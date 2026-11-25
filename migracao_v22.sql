-- v22: marca de "desenvolvedor" na equipe: mesmos poderes do dono, aparece como Desenvolvedor no painel.
alter table public.membros add column if not exists dev boolean not null default false;
grant select (dev) on public.membros to authenticated;
-- aplicado também: conta do dono da Guará criada e ligada à pousada-exemplo como 'dono';
-- conta do desenvolvedor marcada com dev = true (dados, não ficam neste arquivo).
