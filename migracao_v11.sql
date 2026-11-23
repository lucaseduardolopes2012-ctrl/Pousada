-- v11: o sinal é cobrado ANTES do pedido chegar ao painel.
-- Quando a pousada tem chave Pix e sinal (%) configurados, o pedido do site nasce como
-- 'aguardando_pagamento' (não aparece em "pedidos novos" e não ocupa o quarto). Assim que o valor
-- recebido (sinal_pago) chega ao sinal exigido, ele é APROVADO sozinho ('confirmada').
-- Quem registra o valor recebido: o dono, no painel (ou, no futuro, um webhook de um provedor de
-- pagamento que atualize reservas.sinal_pago). Pedidos sem pagamento em 24 h são cancelados.

alter table public.reservas drop constraint if exists reservas_status_check;
alter table public.reservas add constraint reservas_status_check
  check (status in ('aguardando_pagamento', 'solicitada', 'confirmada', 'hospedado', 'finalizada', 'cancelada', 'no_show'));

-- sinal exigido: % do total da pousada (0 quando ela não cobra sinal ou não tem chave Pix)
create or replace function public.sinal_exigido(p_pousada uuid, p_total numeric)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select round(coalesce(p_total, 0) * sinal_percentual / 100.0, 2)
                     from public.pousadas where id = p_pousada and pix_chave <> '' and sinal_percentual > 0), 0);
$$;
revoke execute on function public.sinal_exigido(uuid, numeric) from public, anon, authenticated;

-- aprovação automática quando o sinal é pago
create or replace function public.reservas_aprova_pagamento()
returns trigger language plpgsql security definer set search_path = public as $$
declare exigido numeric;
begin
  if new.status = 'aguardando_pagamento' and new.sinal_pago > old.sinal_pago then
    exigido := public.sinal_exigido(new.pousada_id, new.valor_total);
    if exigido > 0 and new.sinal_pago + 0.005 >= exigido then new.status := 'confirmada'; end if;
  end if;
  return new;
end $$;
drop trigger if exists reservas_aprova_pagamento on public.reservas;
create trigger reservas_aprova_pagamento before update of sinal_pago on public.reservas
  for each row execute function public.reservas_aprova_pagamento();

-- o pedido do site nasce aguardando o pagamento quando a pousada cobra sinal
create or replace function public.solicitar_reserva(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos integer, p_criancas integer, p_nome text, p_telefone text, p_email text, p_obs text)
returns bigint language plpgsql security definer set search_path to 'public' as $$
declare pid uuid; q public.quartos; tel text; cod bigint; por_hora int; por_dia int; da_pousada int; cobra boolean;
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then
    raise exception 'Escolha datas válidas.';
  end if;
  if length(trim(coalesce(p_nome, ''))) < 2 or length(p_nome) > 100 then raise exception 'Informe seu nome.'; end if;
  tel := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  if length(tel) < 10 or length(tel) > 13 then raise exception 'Informe um telefone com DDD.'; end if;
  if length(coalesce(p_email, '')) > 120 or length(coalesce(p_obs, '')) > 500 then raise exception 'Texto muito longo.'; end if;
  if coalesce(p_adultos, 0) < 1 or coalesce(p_criancas, 0) < 0 or p_adultos > 20 or p_criancas > 20 then raise exception 'Quantidade de hóspedes inválida.'; end if;
  select id, (pix_chave <> '' and sinal_percentual > 0) into pid, cobra from public.pousadas where slug = p_slug and ativo and situacao = 'aprovada';
  if pid is null then raise exception 'Pousada não encontrada.'; end if;
  select * into q from public.quartos where id = p_quarto and pousada_id = pid and ativo;
  if q.id is null then raise exception 'Quarto indisponível.'; end if;
  if p_adultos + p_criancas > q.capacidade then raise exception 'Esse quarto comporta até % pessoas.', q.capacidade; end if;
  if exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida)) then
    raise exception 'Esse quarto acabou de ficar indisponível nessas datas.';
  end if;
  -- pedidos que ficaram 24 h sem pagar o sinal são cancelados
  update public.reservas set status = 'cancelada' where pousada_id = pid and status = 'aguardando_pagamento' and criado_em < now() - interval '24 hours';
  select count(*) into por_hora from public.reservas where pousada_id = pid and status in ('solicitada', 'aguardando_pagamento') and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '1 hour';
  if por_hora >= 3 then raise exception 'Você já enviou pedidos recentemente. Aguarde a resposta da pousada.'; end if;
  select count(*) into por_dia from public.reservas where pousada_id = pid and status in ('solicitada', 'aguardando_pagamento') and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '24 hours';
  if por_dia >= 6 then raise exception 'Muitos pedidos deste telefone hoje. Fale direto com a pousada.'; end if;
  select count(*) into da_pousada from public.reservas where pousada_id = pid and status in ('solicitada', 'aguardando_pagamento') and criado_em > now() - interval '1 hour';
  if da_pousada >= 20 then raise exception 'Muitos pedidos agora. Tente de novo mais tarde.'; end if;
  insert into public.reservas (pousada_id, quarto_id, nome, telefone, email, adultos, criancas, entrada, saida, status, origem, observacoes)
  values (pid, q.id, trim(p_nome), trim(p_telefone), trim(coalesce(p_email, '')), p_adultos, p_criancas, p_entrada, p_saida,
          case when cobra then 'aguardando_pagamento' else 'solicitada' end, 'site', trim(coalesce(p_obs, '')))
  returning codigo into cod;
  return cod;
end $$;

-- consulta do hóspede: agora também informa o sinal exigido e até quando pagar
create or replace function public.consultar_pedido(p_slug text, p_codigo bigint, p_telefone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g'); r jsonb;
begin
  if p_codigo is null or p_codigo < 1 or length(tel) < 10 or length(tel) > 13 then
    perform pg_sleep(0.4); return null;
  end if;
  select jsonb_build_object(
      'codigo', x.codigo,
      'status', case when x.status = 'aguardando_pagamento' and x.criado_em < now() - interval '24 hours' then 'expirada' else x.status end,
      'nome', split_part(trim(x.nome), ' ', 1),
      'quarto', q.nome, 'entrada', x.entrada, 'saida', x.saida, 'adultos', x.adultos, 'criancas', x.criancas,
      'valor_total', case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end,
      'sinal_pago', x.sinal_pago, 'criado_em', x.criado_em,
      'sinal_exigido', public.sinal_exigido(x.pousada_id, case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end),
      'expira_em', x.criado_em + interval '24 hours')
    into r
    from public.reservas x
    join public.pousadas p on p.id = x.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
    join public.quartos q on q.id = x.quarto_id
   where x.codigo = p_codigo and right(regexp_replace(x.telefone, '\D', '', 'g'), 8) = right(tel, 8);
  if r is null then perform pg_sleep(0.4); end if;
  return r;
end $$;
revoke execute on function public.consultar_pedido(text, bigint, text) from public;
grant execute on function public.consultar_pedido(text, bigint, text) to anon, authenticated;
