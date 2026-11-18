-- v13: o dono decide ANTES do pagamento.
-- Fluxo: o pedido do site nasce 'solicitada' (pendente). O dono aceita ou recusa.
--  - sem sinal: aceitar = confirmar direto (como antes).
--  - com sinal: ACEITAR vira 'aguardando_pagamento' -> o quarto fica reservado por 24h e o
--    hóspede paga o sinal pelo site; pago o sinal, confirma sozinho; sem pagar em 24h, cancela.
-- (antes, com sinal, o pedido já nascia aguardando pagamento e pulava o dono.)

-- início do prazo de 24h: quando o pedido passou a aguardar o pagamento (após o aceite)
alter table public.reservas add column if not exists aguardando_desde timestamptz;
update public.reservas set aguardando_desde = coalesce(aguardando_desde, criado_em) where status = 'aguardando_pagamento';

-- enquanto aguarda o pagamento (reserva já aceita) o quarto fica bloqueado, como confirmada/hospedado
alter table public.reservas drop constraint if exists reservas_quarto_id_daterange_excl;
alter table public.reservas add constraint reservas_quarto_id_daterange_excl
  exclude using gist (quarto_id with =, daterange(entrada, saida) with &&)
  where (status in ('aguardando_pagamento', 'confirmada', 'hospedado'));

-- carimba o início do prazo quando o pedido passa a aguardar o pagamento
create or replace function public.reservas_marca_aguardando()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'aguardando_pagamento' and old.status is distinct from 'aguardando_pagamento' then
    new.aguardando_desde := now();
  end if;
  return new;
end $$;
drop trigger if exists reservas_marca_aguardando on public.reservas;
create trigger reservas_marca_aguardando before update of status on public.reservas
  for each row execute function public.reservas_marca_aguardando();

-- o pedido do site nasce SEMPRE pendente (o dono decide)
create or replace function public.solicitar_reserva(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos integer, p_criancas integer, p_nome text, p_telefone text, p_email text, p_obs text)
returns bigint language plpgsql security definer set search_path to 'public' as $$
declare pid uuid; q public.quartos; tel text; cod bigint; por_hora int; por_dia int; da_pousada int;
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then
    raise exception 'Escolha datas válidas.';
  end if;
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
  if exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('aguardando_pagamento', 'confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida)) then
    raise exception 'Esse quarto acabou de ficar indisponível nessas datas.';
  end if;
  -- reservas aceitas que ficaram 24 h sem pagar o sinal são canceladas e liberam o quarto
  update public.reservas set status = 'cancelada' where pousada_id = pid and status = 'aguardando_pagamento' and coalesce(aguardando_desde, criado_em) < now() - interval '24 hours';
  select count(*) into por_hora from public.reservas where pousada_id = pid and status in ('solicitada', 'aguardando_pagamento') and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '1 hour';
  if por_hora >= 3 then raise exception 'Você já enviou pedidos recentemente. Aguarde a resposta da pousada.'; end if;
  select count(*) into por_dia from public.reservas where pousada_id = pid and status in ('solicitada', 'aguardando_pagamento') and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '24 hours';
  if por_dia >= 6 then raise exception 'Muitos pedidos deste telefone hoje. Fale direto com a pousada.'; end if;
  select count(*) into da_pousada from public.reservas where pousada_id = pid and status in ('solicitada', 'aguardando_pagamento') and criado_em > now() - interval '1 hour';
  if da_pousada >= 20 then raise exception 'Muitos pedidos agora. Tente de novo mais tarde.'; end if;
  insert into public.reservas (pousada_id, quarto_id, nome, telefone, email, adultos, criancas, entrada, saida, status, origem, observacoes)
  values (pid, q.id, trim(p_nome), trim(p_telefone), trim(coalesce(p_email, '')), p_adultos, p_criancas, p_entrada, p_saida, 'solicitada', 'site', trim(coalesce(p_obs, '')))
  returning codigo into cod;
  return cod;
end $$;

-- consulta do hóspede: o prazo de 24h conta a partir do aceite (aguardando_desde)
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
      'quarto', q.nome, 'entrada', x.entrada, 'saida', x.saida, 'adultos', x.adultos, 'criancas', x.criancas,
      'valor_total', case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end,
      'sinal_pago', x.sinal_pago, 'criado_em', x.criado_em,
      'sinal_exigido', public.sinal_exigido(x.pousada_id, case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end),
      'expira_em', coalesce(x.aguardando_desde, x.criado_em) + interval '24 hours',
      'pix_chave', (select pix_chave from public.pousadas where id = x.pousada_id))
    into r
    from public.reservas x
    join public.pousadas p on p.id = x.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
    join public.quartos q on q.id = x.quarto_id
   where x.codigo = p_codigo and right(regexp_replace(x.telefone, '\D', '', 'g'), 8) = right(tel, 8);
  if r is null then insert into public.consulta_limite (ip, slug) values (v_ip, p_slug); end if;
  return r;
end $$;
revoke execute on function public.consultar_pedido(text, bigint, text) from public;
grant execute on function public.consultar_pedido(text, bigint, text) to anon, authenticated;
