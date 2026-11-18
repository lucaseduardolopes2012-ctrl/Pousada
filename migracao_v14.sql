-- v14 (Stripe, cartão): reconciliação do pagamento por cartão.
-- O Pix direto continua como está. Para cartão, a Edge Function cria uma sessão de
-- Checkout na Stripe; quando a Stripe confirma (webhook), gravamos sinal_pago e o
-- gatilho que já existe (reservas_aprova_pagamento) confirma a reserva sozinho.
alter table public.reservas
  add column if not exists stripe_session_id text,
  add column if not exists pago_via text check (pago_via in ('pix', 'cartao', 'manual') or pago_via is null);
create index if not exists reservas_stripe_session on public.reservas (stripe_session_id);
-- Quem escreve estas colunas é a Edge Function com a service_role (contorna o RLS).
-- anon/authenticated NÃO recebem grant nelas, de propósito.
