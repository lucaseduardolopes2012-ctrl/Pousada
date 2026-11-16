-- v6: registro do aceite dos Termos de Uso pela pousada (prova de contrato e das instruções de tratamento de dados, LGPD art. 39).
alter table public.pousadas
  add column if not exists termos_versao text check (termos_versao is null or length(termos_versao) <= 20),
  add column if not exists termos_aceitos_em timestamptz,
  add column if not exists termos_aceitos_por uuid references auth.users on delete set null;
grant select (termos_versao, termos_aceitos_em) on public.pousadas to authenticated;

-- Só o dono da pousada registra o aceite, e só para a própria pousada.
create or replace function public.aceitar_termos(p_versao text) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Entre na sua conta primeiro.'; end if;
  if p_versao is null or p_versao !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'Versão dos termos inválida.'; end if;
  update public.pousadas set termos_versao = p_versao, termos_aceitos_em = now(), termos_aceitos_por = uid
  where id in (select pousada_id from public.membros where user_id = uid and papel = 'dono');
  if not found then raise exception 'Só o dono da pousada pode aceitar os termos.'; end if;
end $$;
revoke execute on function public.aceitar_termos(text) from public, anon;
grant execute on function public.aceitar_termos(text) to authenticated;
