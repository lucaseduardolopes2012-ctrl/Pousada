-- v18: a avaliação só abre depois do fim da estadia: quando a pousada registra a saída (finalizada)
-- ou quando já passou o horário de saída do último dia. Antes disso (inclusive no dia da saída, antes do horário), não abre.
create or replace function public.estadia_acabou(p_reserva uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select x.status = 'finalizada'
      or (x.status in ('hospedado', 'confirmada')
          and (x.saida < public.hoje_br()
               or (x.saida = public.hoje_br() and (now() at time zone 'America/Sao_Paulo')::time >= p.checkout_hora::time)))
    from public.reservas x join public.pousadas p on p.id = x.pousada_id where x.id = p_reserva), false);
$$;
revoke execute on function public.estadia_acabou(uuid) from public, anon, authenticated;

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
  if not public.estadia_acabou(x.id) then raise exception 'A avaliação abre depois do fim da estadia.'; end if;
  if exists (select 1 from public.avaliacoes where reserva_id = x.id) then raise exception 'Você já avaliou essa estadia. Obrigado!'; end if;
  insert into public.avaliacoes (pousada_id, reserva_id, nota, texto, nome)
  values (x.pousada_id, x.id, p_nota, trim(coalesce(p_texto, '')), left(split_part(trim(x.nome), ' ', 1), 60));
  return true;
end $$;

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
      'pode_avaliar', public.estadia_acabou(x.id))
    into r
    from public.reservas x
    join public.pousadas p on p.id = x.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
    join public.quartos q on q.id = x.quarto_id
   where x.codigo = p_codigo and right(regexp_replace(x.telefone, '\D', '', 'g'), 8) = right(tel, 8);
  if r is null then insert into public.consulta_limite (ip, slug) values (v_ip, p_slug); end if;
  return r;
end $$;
