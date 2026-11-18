// Edge Function: cria uma sessão de Stripe Checkout para o hóspede pagar o SINAL no cartão.
// O hóspede se autentica como no site: número do pedido + telefone (últimos 8 dígitos).
// Só cria a cobrança se o pedido já foi ACEITO pela pousada (status 'aguardando_pagamento').
// Deploy: supabase functions deploy criar-pagamento-cartao
// Segredos necessários: STRIPE_SECRET_KEY, PUBLIC_SITE_URL
//   (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são injetados automaticamente)
import Stripe from "npm:stripe@18.5.0";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, { apiVersion: "2025-08-27.basil", httpClient: Stripe.createFetchHttpClient() });
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const SITE = (Deno.env.get("PUBLIC_SITE_URL") ?? "").replace(/\/+$/, "");
const so8 = (t: string) => (t || "").replace(/\D/g, "").slice(-8);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ erro: "Método inválido." }, 405);
  try {
    const { slug, codigo, telefone } = await req.json().catch(() => ({}));
    if (!/^[a-z0-9-]{3,40}$/.test(slug ?? "") || !Number.isInteger(codigo) || so8(telefone ?? "").length < 8) {
      return json({ erro: "Dados incompletos." }, 400);
    }
    // busca a pousada, depois a reserva, conferindo os últimos 8 dígitos do telefone (service_role)
    const { data: pous, error: ep } = await db
      .from("pousadas").select("id, nome, sinal_percentual").eq("slug", slug).eq("ativo", true).maybeSingle();
    if (ep || !pous) return json({ erro: "Pousada não encontrada." }, 404);
    const { data: linhas, error } = await db
      .from("reservas").select("id, status, telefone, valor_total, sinal_pago, entrada, saida, quarto_id")
      .eq("codigo", codigo).eq("pousada_id", pous.id).limit(5);
    if (error) return json({ erro: "Falha ao ler o pedido." }, 500);
    const r = (linhas ?? []).find((x) => so8(x.telefone) === so8(telefone));
    if (!r) return json({ erro: "Pedido não encontrado. Confira o número e o telefone." }, 404);
    if (r.status !== "aguardando_pagamento") {
      return json({ erro: "Este pedido não está aguardando pagamento." }, 409);
    }
    let total = Number(r.valor_total);
    if (!(total > 0)) {
      const { data: qt } = await db.from("quartos").select("diaria").eq("id", r.quarto_id).maybeSingle();
      total = Number(qt?.diaria || 0) * ((new Date(r.saida).getTime() - new Date(r.entrada).getTime()) / 86400000);
    }
    const pct = Number(pous.sinal_percentual) || 0;
    const sinal = pct > 0 && pct < 100 ? Math.round(total * pct) / 100 : total;
    const falta = Math.max(0, Math.round((sinal - Number(r.sinal_pago || 0)) * 100) / 100);
    if (!(falta > 0)) return json({ erro: "Nada a pagar." }, 409);

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: ["card"],
      line_items: [{
        quantity: 1,
        price_data: {
          currency: "brl",
          unit_amount: Math.round(falta * 100),
          product_data: { name: `Sinal da reserva #${String(codigo).padStart(5, "0")} — ${pous.nome}` },
        },
      }],
      metadata: { reserva_id: r.id, codigo: String(codigo), slug },
      success_url: `${SITE}/reserva.html?p=${encodeURIComponent(slug)}&c=${codigo}&pago=1`,
      cancel_url: `${SITE}/reserva.html?p=${encodeURIComponent(slug)}&c=${codigo}`,
    });
    return json({ url: session.url });
  } catch (e) {
    return json({ erro: "Não deu para iniciar o pagamento." }, 500);
  }
});
