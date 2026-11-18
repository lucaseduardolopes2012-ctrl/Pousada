# Pagamento por cartão com Stripe (Edge Functions)

O Pix direto continua como está (grátis, confirmação manual pelo painel).
Estas funções adicionam **cartão pela Stripe com confirmação automática**:

1. `criar-pagamento-cartao` — o hóspede, já **aceito** pela pousada, clica em "Pagar com cartão".
   A função cria uma sessão de **Stripe Checkout** com o valor do sinal e devolve a URL.
2. `stripe-webhook` — quando a Stripe confirma o pagamento, grava `sinal_pago` na reserva.
   O gatilho `reservas_aprova_pagamento` (já existe no banco) muda o status para `confirmada`.

> ✅ **Já publicado no Supabase e testado em modo teste** (sk_test):
> criação da sessão de Checkout, webhook com assinatura real e confirmação
> automática da reserva pelo gatilho — tudo verificado.
> O botão "Pagar com cartão" no site está **desligado** (`CARTAO_ATIVO=false`
> em reserva.html); só aparece com `?cartao=1` na URL, para você testar.

## Passo a passo para ativar (teste primeiro)

Pré‑requisitos: conta na Stripe e o [Supabase CLI](https://supabase.com/docs/guides/cli).

```bash
# 1. Aplicar a migração das colunas (no SQL editor do Supabase ou via CLI)
#    arquivo: migracao_v14.sql

# 2. Guardar os segredos (use as chaves de TESTE primeiro — começam com sk_test_)
supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx
supabase secrets set PUBLIC_SITE_URL=https://pousada-gestao-theta.vercel.app

# 3. Publicar as funções
supabase functions deploy criar-pagamento-cartao
supabase functions deploy stripe-webhook --no-verify-jwt

# 4. Registrar o webhook na Stripe apontando para:
#    https://<PROJECT_REF>.supabase.co/functions/v1/stripe-webhook
#    evento: checkout.session.completed
#    copie o "Signing secret" (whsec_...) e guarde:
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_xxx
```

## Teste de ponta a ponta (modo teste da Stripe)
1. No site, faça um pedido numa pousada que cobra sinal.
2. No painel, **Aceite** o pedido.
3. Na página do pedido, clique em **Pagar com cartão** e use o cartão de teste `4242 4242 4242 4242`, validade futura, CVC qualquer.
4. O webhook deve gravar o sinal e a reserva vira **Confirmada** sozinha.

## Ir para produção (dinheiro real)
1. Troque os segredos pelas chaves `sk_live_…` e recrie o webhook em modo live
   (novo `whsec_…`). Me avise que eu faço isso.
2. Em `reserva.html`, mude `CARTAO_ATIVO` para `true` para o botão aparecer
   para todos os hóspedes.
