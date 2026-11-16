# Painel de quartos da pousada

Painel interno: quem está hospedado, quem sai hoje e quem atrasou a saída.

- `painel.html`: o painel (rotas `#geral`, `#quartos`, `#quarto-<id>`, `#estadias`, `#config`).
- `comecar.html`: cadastro da pousada (nome, quartos, horários e conta).
- `app.css`, `app.js`, `config.js`: estilo e código compartilhado.
- `supabase.sql` e `migracao_v*.sql`: banco (Supabase).
- `deploy.py`: publica na Vercel (rodar uma vez por publicação, de dentro desta pasta).
