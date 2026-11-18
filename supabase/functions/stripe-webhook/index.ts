// Edge Function: recebe o webhook da Stripe e confirma o pagamento do sinal.
// Em 'checkout.session.completed' (pago), grava sinal_pago na reserva pelo id que veio nos
// metadados. O gatilho reservas_aprova_pagamento então muda o status para 'confirmada'.
// Deploy: supabase functions deploy stripe-webhook --no-verify-jwt
//   (--no-verify-jwt: a Stripe chama sem o JWT do Supabase; a autenticidade vem da ASSINATURA)
// Segredos necessários: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
import Stripe from "npm:stripe@18.5.0";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, { apiVersion: "2025-08-27.basil", httpClient: Stripe.createFetchHttpClient() });
const cryptoProvider = Stripe.createSubtleCryptoProvider();
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const SEGREDO = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

Deno.serve(async (req) => {
  const assinatura = req.headers.get("stripe-signature");
  const corpo = await req.text();
  let evento: Stripe.Event;
  try {
    evento = await stripe.webhooks.constructEventAsync(corpo, assinatura!, SEGREDO, undefined, cryptoProvider);
  } catch {
    return new Response("assinatura inválida", { status: 400 });
  }

  if (evento.type === "checkout.session.completed") {
    const s = evento.data.object as Stripe.Checkout.Session;
    const reservaId = s.metadata?.reserva_id;
    if (s.payment_status === "paid" && reservaId) {
      const valor = (s.amount_total ?? 0) / 100;
      // idempotente: só grava se ainda não registramos esta sessão
      const { data: atual } = await db.from("reservas").select("sinal_pago, stripe_session_id").eq("id", reservaId).single();
      if (atual && atual.stripe_session_id !== s.id) {
        const novo = Math.max(Number(atual.sinal_pago || 0), valor);
        await db.from("reservas").update({ sinal_pago: novo, stripe_session_id: s.id, pago_via: "cartao" }).eq("id", reservaId);
      }
    }
  }
  return new Response("ok", { status: 200 });
});
