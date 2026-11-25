// Manda a notificação "pedido de estadia novo" para o celular do dono (app Android, via Firebase).
// Chamada pelo banco (gatilho t_avisa_reserva_nova) logo depois que o hóspede envia a ficha pelo site.
// Não precisa de senha: só avisa pedidos criados há menos de 10 minutos e cada pedido uma vez só.
import { createClient } from "jsr:@supabase/supabase-js@2";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const b64url = (b: ArrayBuffer | Uint8Array | string) => {
  const bytes = typeof b === "string" ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = ""; for (const x of bytes) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

let cache: { token: string; ate: number } | null = null;
async function tokenGoogle(conta: { client_email: string; private_key: string }) {
  if (cache && cache.ate > Date.now() + 60_000) return cache.token;
  const agora = Math.floor(Date.now() / 1000);
  const cab = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const corpo = b64url(JSON.stringify({
    iss: conta.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: agora, exp: agora + 3600,
  }));
  const pem = conta.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const chave = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const ass = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", chave, new TextEncoder().encode(`${cab}.${corpo}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${cab}.${corpo}.${b64url(ass)}` }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("Google recusou a conta de serviço: " + JSON.stringify(j));
  cache = { token: j.access_token, ate: Date.now() + (j.expires_in ?? 3600) * 1000 };
  return cache.token;
}

const data = (d: string) => d.split("-").reverse().slice(0, 2).join("/");

Deno.serve(async (req) => {
  try {
    const { id } = await req.json().catch(() => ({}));
    if (typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) return new Response("id?", { status: 400 });

    // marca como avisado antes de enviar: dois disparos do mesmo pedido não geram dois avisos
    const desde = new Date(Date.now() - 10 * 60_000).toISOString();
    const { data: r } = await sb.from("reservas").update({ push_enviado: true })
      .eq("id", id).eq("push_enviado", false).eq("origem", "site").gte("criado_em", desde)
      .select("codigo, nome, entrada, saida, adultos, criancas, pousada_id, quarto:quartos(nome)").maybeSingle();
    if (!r) return new Response("nada a avisar");

    const { data: tokens } = await sb.from("push_tokens").select("token").eq("pousada_id", r.pousada_id);
    if (!tokens?.length) return new Response("sem celular cadastrado");

    const bruto = Deno.env.get("FCM_CONTA");
    if (!bruto) return new Response("falta o segredo FCM_CONTA", { status: 500 });
    const conta = JSON.parse(bruto);
    const acesso = await tokenGoogle(conta);

    const pessoas = `${r.adultos} adulto${r.adultos === 1 ? "" : "s"}` + (r.criancas ? ` + ${r.criancas} criança${r.criancas === 1 ? "" : "s"}` : "");
    const quarto = (r.quarto as { nome?: string } | null)?.nome ?? "";
    const titulo = `Pedido de estadia novo #${r.codigo}`;
    const texto = `${String(r.nome).trim().split(/\s+/)[0]} · ${quarto ? quarto + " · " : ""}${data(r.entrada)} a ${data(r.saida)} · ${pessoas}`;

    let enviados = 0;
    for (const { token } of tokens) {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${conta.project_id}/messages:send`, {
        method: "POST", headers: { Authorization: `Bearer ${acesso}`, "Content-Type": "application/json" },
        body: JSON.stringify({ message: {
          token,
          notification: { title: titulo, body: texto },
          data: { codigo: String(r.codigo) },
          android: { priority: "HIGH", notification: { channel_id: "reservas", sound: "default", color: "#e30613", tag: `pedido-${r.codigo}` } },
        } }),
      });
      if (res.ok) { enviados++; continue; }
      const erro = await res.text();
      if (res.status === 404 || erro.includes("UNREGISTERED")) await sb.from("push_tokens").delete().eq("token", token); // app desinstalado
      else console.error("FCM", res.status, erro);
    }
    return new Response(`enviados: ${enviados}`);
  } catch (e) {
    console.error(e);
    return new Response("erro", { status: 500 });
  }
});
