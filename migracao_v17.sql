-- v17: (1) cobrança por quarto ou por pessoa, com a idade das crianças (até 5 anos não paga; acima de 5 paga a diária inteira);
--      (2) o hóspede pede o cancelamento pela página "Acompanhar pedido";
--      (3) avaliações depois da estadia, que aparecem direto no site.

-- ---------- (1) cobrança ----------
alter table public.pousadas add column if not exists cobranca text not null default 'quarto';
alter table public.pousadas drop constraint if exists pousadas_cobranca_ok;
alter table public.pousadas add constraint pousadas_cobranca_ok check (cobranca in ('quarto', 'pessoa'));
grant select (cobranca), update (cobranca) on public.pousadas to authenticated;

alter table public.reservas add column if not exists criancas_idades int[] not null default '{}';
alter table public.reservas drop constraint if exists reservas_idades_ok;
alter table public.reservas add constraint reservas_idades_ok check (cardinality(criancas_idades) <= 20 and 0 <= all(criancas_idades) and 17 >= all(criancas_idades));

-- quantas pessoas pagam a diária: por quarto = 1; por pessoa = adultos + crianças acima de 5 anos.
-- Criança sem idade informada (ex.: estadia lançada no balcão) conta como pagante.
create or replace function public.pagantes(p_pousada uuid, p_adultos int, p_criancas int, p_idades int[])
returns int language sql stable security definer set search_path = public as $$
  select case when (select cobranca from public.pousadas where id = p_pousada) = 'pessoa'
    then greatest(1, coalesce(p_adultos, 1)
      + (select count(*)::int from unnest(coalesce(p_idades, '{}')) i where i > 5)
      + greatest(0, coalesce(p_criancas, 0) - cardinality(coalesce(p_idades, '{}'))))
    else 1 end;
$$;
revoke execute on function public.pagantes(uuid, int, int, int[]) from public, anon, authenticated;

create or replace function public.reservas_antes_de_gravar()
returns trigger language plpgsql security definer set search_path = public as $$
declare d numeric;
begin
  if tg_op = 'INSERT' and coalesce(new.valor_total, 0) = 0 then
    select diaria into d from public.quartos where id = new.quarto_id;
    new.valor_total := coalesce(d, 0) * (new.saida - new.entrada) * public.pagantes(new.pousada_id, new.adultos, new.criancas, new.criancas_idades);
  end if;
  return new;
end $$;

-- busca com hóspedes: o total já sai certo para cobrança por quarto ou por pessoa
create or replace function public.quartos_disponiveis(p_slug text, p_entrada date, p_saida date, p_adultos int, p_idades int[])
returns table(id uuid, nome text, tipo text, capacidade integer, diaria numeric, descricao text, foto_url text, noites integer, pagantes integer, total numeric)
language plpgsql stable security definer set search_path = public as $$
declare pid uuid; n int;
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then
    raise exception 'Escolha datas válidas: a saída depois da chegada e a chegada a partir de hoje.';
  end if;
  if coalesce(p_adultos, 0) < 1 or p_adultos > 20 or cardinality(coalesce(p_idades, '{}')) > 20 or exists (select 1 from unnest(coalesce(p_idades, '{}')) i where i < 0 or i > 17) then
    raise exception 'Confira o número de hóspedes e a idade das crianças.';
  end if;
  select p.id into pid from public.pousadas p where p.slug = p_slug and p.ativo and p.situacao = 'aprovada';
  n := public.pagantes(pid, p_adultos, cardinality(coalesce(p_idades, '{}')), coalesce(p_idades, '{}'));
  return query
    select q.id, q.nome, q.tipo, q.capacidade, q.diaria, q.descricao, q.foto_url, (p_saida - p_entrada)::int, n, ((p_saida - p_entrada) * q.diaria * n)::numeric
    from public.quartos q
    where q.pousada_id = pid and q.ativo
      and not exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida))
    order by q.diaria, q.nome;
end $$;
revoke execute on function public.quartos_disponiveis(text, date, date, int, int[]) from public;
grant execute on function public.quartos_disponiveis(text, date, date, int, int[]) to anon, authenticated;

-- pedido com a idade das crianças: grava as idades e recalcula o valor
create or replace function public.pedir_estadia(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos int, p_criancas int, p_nome text, p_telefone text, p_documento text, p_email text, p_obs text, p_idades int[])
returns bigint language plpgsql security definer set search_path = public as $$
declare cod bigint; ids int[] := coalesce(p_idades, '{}');
begin
  if cardinality(ids) <> coalesce(p_criancas, 0) then raise exception 'Informe a idade de cada criança.'; end if;
  if exists (select 1 from unnest(ids) i where i < 0 or i > 17) then raise exception 'Idade de criança inválida.'; end if;
  cod := public.pedir_estadia(p_slug, p_quarto, p_entrada, p_saida, p_adultos, p_criancas, p_nome, p_telefone, p_documento, p_email, p_obs);
  update public.reservas r set criancas_idades = ids,
         valor_total = q.diaria * (r.saida - r.entrada) * public.pagantes(r.pousada_id, r.adultos, r.criancas, ids)
    from public.quartos q where r.codigo = cod and q.id = r.quarto_id;
  return cod;
end $$;
revoke execute on function public.pedir_estadia(text, uuid, date, date, int, int, text, text, text, text, text, int[]) from public;
grant execute on function public.pedir_estadia(text, uuid, date, date, int, int, text, text, text, text, text, int[]) to anon, authenticated;

-- ---------- (2) cancelamento pedido pelo hóspede ----------
alter table public.reservas add column if not exists cancelamento_pedido_em timestamptz;
alter table public.reservas add column if not exists cancelamento_motivo text not null default '';
alter table public.reservas drop constraint if exists reservas_cancel_motivo_ok;
alter table public.reservas add constraint reservas_cancel_motivo_ok check (length(cancelamento_motivo) <= 300);
grant select (criancas_idades, cancelamento_pedido_em, cancelamento_motivo) on public.reservas to authenticated;
grant update (criancas_idades, cancelamento_pedido_em) on public.reservas to authenticated;
grant insert (criancas_idades) on public.reservas to authenticated;

-- Pedido que a pousada ainda não confirmou (e sem nada pago) cancela na hora. Reserva confirmada ou com pagamento
-- vira um pedido de cancelamento, que aparece no painel para a pousada decidir. Devolve 'cancelada' ou 'pedido'.
create or replace function public.pedir_cancelamento(p_slug text, p_codigo bigint, p_telefone text, p_motivo text)
returns text language plpgsql security definer set search_path = public as $$
declare
  tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  v_ip text := coalesce(nullif(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'desconhecido');
  x public.reservas;
begin
  delete from public.consulta_limite where em < now() - interval '10 minutes';
  if (select count(*) from public.consulta_limite where ip = v_ip and em > now() - interval '1 minute') >= 15 then
    raise exception 'Muitas tentativas. Aguarde um minuto e tente de novo.';
  end if;
  if length(coalesce(p_motivo, '')) > 300 then raise exception 'O motivo pode ter até 300 letras.'; end if;
  select r.* into x from public.reservas r join public.pousadas p on p.id = r.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
   where r.codigo = p_codigo and length(tel) >= 10 and right(regexp_replace(r.telefone, '\D', '', 'g'), 8) = right(tel, 8);
  if x.id is null then insert into public.consulta_limite (ip, slug) values (v_ip, p_slug); raise exception 'Pedido não encontrado. Confira o número e o telefone.'; end if;
  if x.status in ('cancelada', 'no_show') then raise exception 'Esse pedido já está cancelado.'; end if;
  if x.status in ('hospedado', 'finalizada') then raise exception 'A estadia já começou. Fale com a pousada.'; end if;
  if x.status in ('solicitada', 'aguardando_pagamento') and coalesce(x.sinal_pago, 0) = 0 then
    update public.reservas set status = 'cancelada', cancelamento_pedido_em = now(), cancelamento_motivo = trim(coalesce(p_motivo, '')) where id = x.id;
    return 'cancelada';
  end if;
  update public.reservas set cancelamento_pedido_em = now(), cancelamento_motivo = trim(coalesce(p_motivo, '')) where id = x.id;
  return 'pedido';
end $$;
revoke execute on function public.pedir_cancelamento(text, bigint, text, text) from public;
grant execute on function public.pedir_cancelamento(text, bigint, text, text) to anon, authenticated;

-- ---------- (3) avaliações ----------
create table if not exists public.avaliacoes (
  id uuid primary key default gen_random_uuid(),
  pousada_id uuid not null references public.pousadas on delete cascade,
  reserva_id uuid not null unique references public.reservas on delete cascade,
  nota int not null check (nota between 1 and 5),
  texto text not null default '' check (length(texto) <= 1000),
  nome text not null default '' check (length(nome) <= 60),
  criado_em timestamptz not null default now()
);
create index if not exists avaliacoes_pousada_idx on public.avaliacoes (pousada_id, criado_em desc);
alter table public.avaliacoes enable row level security;
drop policy if exists "avaliacoes: equipe ve" on public.avaliacoes;
create policy "avaliacoes: equipe ve" on public.avaliacoes for select to authenticated using (public.is_membro(pousada_id));
drop policy if exists "avaliacoes: dono apaga" on public.avaliacoes;
create policy "avaliacoes: dono apaga" on public.avaliacoes for delete to authenticated using (public.is_dono(pousada_id));
revoke all on public.avaliacoes from anon, authenticated;
grant select, delete on public.avaliacoes to authenticated;

-- O hóspede avalia depois da saída, uma vez por estadia, com o número do pedido e o telefone.
create or replace function public.avaliar_estadia(p_slug text, p_codigo bigint, p_telefone text, p_nota int, p_texto text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  v_ip text := coalesce(nullif(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'desconhecido');
  x public.reservas;
begin
  delete from public.consulta_limite where em < now() - interval '10 minutes';
  if (select count(*) from public.consulta_limite where ip = v_ip and em > now() - interval '1 minute') >= 15 then
    raise exception 'Muitas tentativas. Aguarde um minuto e tente de novo.';
  end if;
  if p_nota is null or p_nota < 1 or p_nota > 5 then raise exception 'Escolha de 1 a 5 estrelas.'; end if;
  if length(coalesce(p_texto, '')) > 1000 then raise exception 'A avaliação pode ter até 1000 letras.'; end if;
  select r.* into x from public.reservas r join public.pousadas p on p.id = r.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
   where r.codigo = p_codigo and length(tel) >= 10 and right(regexp_replace(r.telefone, '\D', '', 'g'), 8) = right(tel, 8);
  if x.id is null then insert into public.consulta_limite (ip, slug) values (v_ip, p_slug); raise exception 'Pedido não encontrado. Confira o número e o telefone.'; end if;
  if not (x.status = 'finalizada' or (x.status in ('hospedado', 'confirmada') and x.saida <= public.hoje_br())) then
    raise exception 'A avaliação abre depois da sua saída.';
  end if;
  if exists (select 1 from public.avaliacoes where reserva_id = x.id) then raise exception 'Você já avaliou essa estadia. Obrigado!'; end if;
  insert into public.avaliacoes (pousada_id, reserva_id, nota, texto, nome)
  values (x.pousada_id, x.id, p_nota, trim(coalesce(p_texto, '')), left(split_part(trim(x.nome), ' ', 1), 60));
  return true;
end $$;
revoke execute on function public.avaliar_estadia(text, bigint, text, int, text) from public;
grant execute on function public.avaliar_estadia(text, bigint, text, int, text) to anon, authenticated;

-- ---------- o site lê cobrança e avaliações; o acompanhamento lê política, cancelamento e avaliação ----------
create or replace function public.site_pousada(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when p.id is null then null else jsonb_build_object(
    'slug', p.slug, 'nome', p.nome, 'cidade', p.cidade, 'bairro', p.bairro,
    'descricao', p.descricao, 'whatsapp', p.whatsapp, 'email', p.email, 'instagram', p.instagram,
    'checkin_hora', p.checkin_hora, 'checkout_hora', p.checkout_hora, 'acesso', p.acesso,
    'como_chegar', p.como_chegar, 'pagamentos', p.pagamentos, 'sinal_percentual', p.sinal_percentual,
    'politica', p.politica, 'fotos', p.fotos, 'tema', p.tema, 'cobranca', p.cobranca,
    'aceita_pix', (p.pix_chave <> ''),
    'cobra_sinal', (p.pix_chave <> '' and p.sinal_percentual > 0),
    'quartos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', q.id, 'nome', q.nome, 'tipo', q.tipo, 'capacidade', q.capacidade,
        'diaria', q.diaria, 'descricao', q.descricao, 'foto_url', q.foto_url) order by q.nome)
      from public.quartos q where q.pousada_id = p.id and q.ativo), '[]'::jsonb),
    'avaliacoes', coalesce((select jsonb_agg(jsonb_build_object('nota', a.nota, 'texto', a.texto, 'nome', a.nome, 'quando', a.criado_em) order by a.criado_em desc)
      from (select * from public.avaliacoes where pousada_id = p.id order by criado_em desc limit 12) a), '[]'::jsonb)
  ) end
  from public.pousadas p where p.slug = p_slug and p.ativo and p.situacao = 'aprovada';
$$;

create or replace function public.consultar_pedido(p_slug text, p_codigo bigint, p_telefone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  v_ip text := coalesce(nullif(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'desconhecido');
  r jsonb;
begin
  delete from public.consulta_limite where em < now() - interval '10 minutes';
  if (select count(*) from public.consulta_limite where ip = v_ip and em > now() - interval '1 minute') >= 15
     or (select count(*) from public.consulta_limite where slug = p_slug and em > now() - interval '1 minute') >= 120 then
    raise exception 'Muitas tentativas. Aguarde um minuto e tente de novo.';
  end if;
  if p_codigo is null or p_codigo < 1 or length(tel) < 10 or length(tel) > 13 then
    insert into public.consulta_limite (ip, slug) values (v_ip, p_slug);
    return null;
  end if;
  select jsonb_build_object(
      'codigo', x.codigo,
      'status', case when x.status = 'aguardando_pagamento' and coalesce(x.aguardando_desde, x.criado_em) < now() - interval '24 hours' then 'expirada' else x.status end,
      'nome', split_part(trim(x.nome), ' ', 1),
      'quarto', q.nome, 'entrada', x.entrada, 'saida', x.saida, 'adultos', x.adultos, 'criancas', x.criancas, 'criancas_idades', x.criancas_idades,
      'valor_total', case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end,
      'sinal_pago', x.sinal_pago, 'criado_em', x.criado_em,
      'sinal_exigido', public.sinal_exigido(x.pousada_id, case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end),
      'expira_em', coalesce(x.aguardando_desde, x.criado_em) + interval '24 hours',
      'pix_chave', p.pix_chave,
      'politica', p.politica, 'cobranca', p.cobranca,
      'cancelamento_pedido_em', x.cancelamento_pedido_em,
      'avaliado', exists (select 1 from public.avaliacoes a where a.reserva_id = x.id),
      'pode_avaliar', (x.status = 'finalizada' or (x.status in ('hospedado', 'confirmada') and x.saida <= public.hoje_br())))
    into r
    from public.reservas x
    join public.pousadas p on p.id = x.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
    join public.quartos q on q.id = x.quarto_id
   where x.codigo = p_codigo and right(regexp_replace(x.telefone, '\D', '', 'g'), 8) = right(tel, 8);
  if r is null then insert into public.consulta_limite (ip, slug) values (v_ip, p_slug); end if;
  return r;
end $$;

-- política de cancelamento inicial da Pousada Guará (a mesma do anúncio dela; o dono pode mudar no painel)
update public.pousadas set politica = 'Cancelamento gratuito até 7 dias depois de fazer a reserva. Depois desse prazo, vale a política combinada com a pousada.'
 where slug = 'pousada-exemplo' and coalesce(politica, '') = '';
