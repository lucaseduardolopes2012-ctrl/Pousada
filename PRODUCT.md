# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Dono ou recepção de uma pousada pequena** (poucos quartos, muitas vezes no litoral, às vezes com acesso só de barco). Usa o painel no balcão e no celular para saber, de relance, quem está hospedado, quem sai hoje, quem atrasou a saída e quem chega. Registra entradas, saídas, estadias e confirma os pedidos que chegam pelo site.
- **Hóspede** que abre o site da pousada (link ou QR code) para ver os quartos, escolher datas, ver o que está livre e mandar um pedido de reserva. A pousada confirma depois, normalmente pelo WhatsApp.

## Product Purpose

Sistema para várias pousadas: qualquer dono se cadastra, ganha um painel interno de quartos e um site público de reservas com o endereço da pousada (`site.html?p=<slug>`). Sucesso para o dono é ocupação clara e nenhuma saída esquecida; para o hóspede, pedir uma reserva em poucos toques sem pagar nada antes da confirmação.

## Positioning

Painel e site feitos para a pousada pequena brasileira, não para hotel: fala em "quarto", "estadia", "sai hoje", "não veio"; trata pedido pelo site como pedido (a pousada confirma), registra quem chega pelo balcão, telefone, WhatsApp ou Booking, e conhece o acesso por barco.

## Operating Context

- Painel: rotas `#geral`, `#quartos`, `#quarto-<id>`, `#estadias`, hóspedes e `#config`. Toca um aviso sonoro quando chega pedido novo. Baixa planilha. Gera link e QR code do site para imprimir.
- Cadastro em 3 passos (`comecar.html`): pousada, quartos e horários, conta.
- Site público por pousada: busca de datas e pessoas, quartos livres com preço da estadia, ficha do hóspede, pedido com código, aviso pelo WhatsApp, galeria de fotos, "bom saber" (horários, como chegar, pagamento, cancelamento).
- Termos de Uso e Aviso de Privacidade (LGPD) com aceite registrado.

## Capabilities and Constraints

- Stack existente: HTML, CSS e JavaScript estáticos, sem build; Supabase (banco, autenticação, RPCs `site_pousada`, `quartos_disponiveis`, `pedir_estadia`) via supabase-js 2.45.4 do jsDelivr; publicação na Vercel (`deploy.py`, `vercel.json` com CSP).
- A CSP só permite scripts de jsDelivr e cdnjs, estilos e fontes do Google Fonts e imagens do próprio site e do Supabase.
- Cada pousada guarda uma cor própria (`cor`, lista em `app.js`: Maré, Mata, Céu, Cara-roxa, Pôr do sol, Areia, Noite) aplicada por `aplicaCor`.
- Situações de estadia: pedido novo, confirmada, hospedado, finalizada, cancelada, não veio.
- Em aberto: nome do produto (ainda não tem; usar nome neutro).

## Brand Commitments

- Idioma português do Brasil, linguagem simples ("Registrar saída", "Pedir reserva").
- Nenhuma marca do produto definida. A paleta antiga (azul-marinho e laranja) não é obrigatória: o dono liberou trocar.

## Evidence on Hand

- Fotos reais da Pousada Guará em `img/pousada-exemplo/` (fachada, 1.jpg 1644×1644; 2.jpg; 3.jpg).
- Não há depoimentos, números de clientes, preços do produto ou logotipo. Não inventar.

## Product Principles

1. O painel responde "quem está aqui, quem sai, quem chega" antes de qualquer outra coisa.
2. Pedido não é reserva: o site nunca promete o que a pousada ainda não confirmou.
3. Cada pousada é a protagonista do próprio site; o produto fica em segundo plano.
4. Funciona bem no celular do dono e no do hóspede, com internet ruim.

## Accessibility & Inclusion

Usuários de todas as idades e pouca familiaridade com tecnologia: textos grandes o bastante, contraste alto, botões com rótulo em palavras, nada que dependa só de cor.
