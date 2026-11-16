-- v3: aprovação antes de ir ao ar
alter table public.pousadas
  add column if not exists situacao text not null default 'pendente' check (situacao in ('pendente', 'aprovada', 'recusada')),
  add column if not exists motivo_recusa text not null default '' check (length(motivo_recusa) <= 500),
  add column if not exists decidido_em timestamptz;
update public.pousadas set situacao = 'aprovada', decidido_em = now() where slug = 'pousada-exemplo' and situacao = 'pendente';
grant select (situacao, motivo_recusa) on public.pousadas to anon, authenticated;

-- quem administra a plataforma (você). Ninguém se adiciona sozinho: só por SQL.
create table if not exists public.plataforma_admins (user_id uuid primary key references auth.users on delete cascade);
alter table public.plataforma_admins enable row level security;
revoke all on public.plataforma_admins from anon, authenticated;

create or replace function public.sou_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.plataforma_admins where user_id = auth.uid())
$$;
revoke execute on function public.sou_admin() from public, anon;
grant execute on function public.sou_admin() to authenticated;

-- só pousada aprovada aparece para o público
drop policy if exists "pousadas: visitante le as ativas" on public.pousadas;
create policy "pousadas: visitante le as ativas" on public.pousadas for select to anon using (ativo and situacao = 'aprovada');
drop policy if exists "pousadas: logado le as ativas ou a sua" on public.pousadas;
create policy "pousadas: logado le as ativas ou a sua" on public.pousadas for select to authenticated using ((ativo and situacao = 'aprovada') or public.is_membro(id) or public.sou_admin());
drop policy if exists "quartos: visitante le os ativos" on public.quartos;
create policy "quartos: visitante le os ativos" on public.quartos for select to anon using (ativo and exists (select 1 from public.pousadas p where p.id = pousada_id and p.ativo and p.situacao = 'aprovada'));
drop policy if exists "quartos: logado le" on public.quartos;
create policy "quartos: logado le" on public.quartos for select to authenticated using ((ativo and exists (select 1 from public.pousadas p where p.id = pousada_id and p.ativo and p.situacao = 'aprovada')) or public.is_membro(pousada_id) or public.sou_admin());

-- busca e pedido de reserva só em pousada aprovada
create or replace function public.quartos_disponiveis(p_slug text, p_entrada date, p_saida date)
returns table (id uuid, nome text, tipo text, capacidade int, diaria numeric, descricao text, foto_url text, noites int, total numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then
    raise exception 'Escolha datas válidas: a saída depois da chegada e a chegada a partir de hoje.';
  end if;
  return query
    select q.id, q.nome, q.tipo, q.capacidade, q.diaria, q.descricao, q.foto_url, (p_saida - p_entrada)::int, ((p_saida - p_entrada) * q.diaria)::numeric
    from public.quartos q join public.pousadas p on p.id = q.pousada_id
    where p.slug = p_slug and p.ativo and p.situacao = 'aprovada' and q.ativo
      and not exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida))
    order by q.diaria, q.nome;
end $$;

create or replace function public.solicitar_reserva(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos int, p_criancas int, p_nome text, p_telefone text, p_email text, p_obs text)
returns bigint language plpgsql security definer set search_path = public as $$
declare pid uuid; q public.quartos; tel text; cod bigint; ativos int; da_pousada int;
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then raise exception 'Escolha datas válidas.'; end if;
  if length(trim(coalesce(p_nome, ''))) < 2 or length(p_nome) > 100 then raise exception 'Informe seu nome.'; end if;
  tel := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  if length(tel) < 10 or length(tel) > 13 then raise exception 'Informe um telefone com DDD.'; end if;
  if length(coalesce(p_email, '')) > 120 or length(coalesce(p_obs, '')) > 500 then raise exception 'Texto muito longo.'; end if;
  if coalesce(p_adultos, 0) < 1 or coalesce(p_criancas, 0) < 0 or p_adultos > 20 or p_criancas > 20 then raise exception 'Quantidade de hóspedes inválida.'; end if;
  select id into pid from public.pousadas where slug = p_slug and ativo and situacao = 'aprovada';
  if pid is null then raise exception 'Pousada não encontrada.'; end if;
  select * into q from public.quartos where id = p_quarto and pousada_id = pid and ativo;
  if q.id is null then raise exception 'Quarto indisponível.'; end if;
  if p_adultos + p_criancas > q.capacidade then raise exception 'Esse quarto comporta até % pessoas.', q.capacidade; end if;
  if exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida)) then
    raise exception 'Esse quarto acabou de ficar indisponível nessas datas.';
  end if;
  select count(*) into ativos from public.reservas where pousada_id = pid and status = 'solicitada' and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '1 hour';
  if ativos >= 3 then raise exception 'Você já enviou pedidos recentemente. Aguarde a resposta da pousada.'; end if;
  select count(*) into da_pousada from public.reservas where pousada_id = pid and status = 'solicitada' and criado_em > now() - interval '1 hour';
  if da_pousada >= 40 then raise exception 'Muitos pedidos agora. Tente de novo mais tarde.'; end if;
  insert into public.reservas (pousada_id, quarto_id, nome, telefone, email, adultos, criancas, entrada, saida, status, origem, observacoes)
  values (pid, q.id, trim(p_nome), trim(p_telefone), trim(coalesce(p_email, '')), p_adultos, p_criancas, p_entrada, p_saida, 'solicitada', 'site', trim(coalesce(p_obs, '')))
  returning codigo into cod;
  return cod;
end $$;

-- painel do administrador
create or replace function public.admin_pousadas(p_situacao text)
returns table (id uuid, slug text, nome text, cidade text, bairro text, acesso text, descricao text, whatsapp text, email text, instagram text, situacao text, motivo_recusa text, criado_em timestamptz, decidido_em timestamptz, dono_email text, quartos bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.sou_admin() then raise exception 'Só o administrador da plataforma pode ver isso.'; end if;
  return query
    select p.id, p.slug, p.nome, p.cidade, p.bairro, p.acesso, p.descricao, p.whatsapp, p.email, p.instagram, p.situacao, p.motivo_recusa, p.criado_em, p.decidido_em,
      (select u.email::text from public.membros m join auth.users u on u.id = m.user_id where m.pousada_id = p.id and m.papel = 'dono' limit 1),
      (select count(*) from public.quartos q where q.pousada_id = p.id)
    from public.pousadas p where p.situacao = p_situacao order by p.criado_em desc limit 200;
end $$;

create or replace function public.decidir_pousada(p_id uuid, p_aprovar boolean, p_motivo text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if not public.sou_admin() then raise exception 'Só o administrador da plataforma pode aprovar ou recusar.'; end if;
  if not p_aprovar and length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'Escreva o motivo da recusa para o dono entender o que ajustar.'; end if;
  update public.pousadas set situacao = case when p_aprovar then 'aprovada' else 'recusada' end,
    motivo_recusa = case when p_aprovar then '' else left(trim(p_motivo), 500) end, decidido_em = now()
  where id = p_id;
  if not found then raise exception 'Pousada não encontrada.'; end if;
  return case when p_aprovar then 'aprovada' else 'recusada' end;
end $$;

-- o dono pede nova análise depois de ajustar
create or replace function public.pedir_nova_analise() returns text
language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  select m.pousada_id into pid from public.membros m where m.user_id = auth.uid() and m.papel = 'dono' limit 1;
  if pid is null then raise exception 'Você não é dono de nenhuma pousada.'; end if;
  update public.pousadas set situacao = 'pendente' where id = pid and situacao = 'recusada';
  if not found then raise exception 'Só dá para pedir nova análise de um cadastro recusado.'; end if;
  return 'pendente';
end $$;

revoke execute on function public.admin_pousadas(text), public.decidir_pousada(uuid, boolean, text), public.pedir_nova_analise() from public, anon;
grant execute on function public.admin_pousadas(text), public.decidir_pousada(uuid, boolean, text), public.pedir_nova_analise() to authenticated;
