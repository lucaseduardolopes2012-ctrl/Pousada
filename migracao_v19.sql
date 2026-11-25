-- v19: aviso no celular do dono quando chega pedido de estadia pelo site.
-- O app Android registra o "endereço" do celular (token do Firebase) e, a cada pedido novo,
-- o banco chama a função avisa-reserva, que manda a notificação.
create extension if not exists pg_net;

create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  pousada_id uuid not null references public.pousadas(id) on delete cascade,
  criado_em timestamptz not null default now()
);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;

-- o celular passa a receber os avisos das pousadas de quem está logado
create or replace function public.salvar_push_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Entre no painel primeiro.'; end if;
  if length(coalesce(p_token, '')) < 20 or length(p_token) > 4096 then raise exception 'Token inválido.'; end if;
  delete from public.push_tokens where token = p_token;
  insert into public.push_tokens (token, user_id, pousada_id)
  select p_token, auth.uid(), m.pousada_id from public.membros m where m.user_id = auth.uid() limit 1;
end $$;

create or replace function public.remover_push_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_tokens where token = p_token and user_id = auth.uid();
$$;
revoke execute on function public.salvar_push_token(text), public.remover_push_token(text) from public, anon;
grant execute on function public.salvar_push_token(text), public.remover_push_token(text) to authenticated;

alter table public.reservas add column if not exists push_enviado boolean not null default false;

create or replace function public.avisa_reserva_nova()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.origem = 'site' and exists (select 1 from public.push_tokens t where t.pousada_id = new.pousada_id) then
    perform net.http_post(
      url := 'https://edybjkudmucoecxebdto.supabase.co/functions/v1/avisa-reserva',
      body := jsonb_build_object('id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  end if;
  return new;
end $$;
revoke execute on function public.avisa_reserva_nova() from public, anon, authenticated;

drop trigger if exists t_avisa_reserva_nova on public.reservas;
create trigger t_avisa_reserva_nova after insert on public.reservas
  for each row execute function public.avisa_reserva_nova();
