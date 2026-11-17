-- v12 (pós-pentest): fecha dois pontos.
--  (1) a chave Pix (às vezes o CPF do dono) não é mais devolvida no load público do site.
--      site_pousada passa a informar só se a pousada cobra sinal / aceita Pix (booleanos).
--      A chave só sai pela consultar_pedido, que já exige número do pedido + telefone.
--  (2) consultar_pedido ganha limite real por IP (antes era só pg_sleep, sem teto).

-- (1) site_pousada sem a chave Pix
create or replace function public.site_pousada(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when p.id is null then null else jsonb_build_object(
    'slug', p.slug, 'nome', p.nome, 'cidade', p.cidade, 'bairro', p.bairro,
    'descricao', p.descricao, 'whatsapp', p.whatsapp, 'email', p.email, 'instagram', p.instagram,
    'checkin_hora', p.checkin_hora, 'checkout_hora', p.checkout_hora, 'acesso', p.acesso,
    'como_chegar', p.como_chegar, 'pagamentos', p.pagamentos, 'sinal_percentual', p.sinal_percentual,
    'politica', p.politica, 'fotos', p.fotos,
    'aceita_pix', (p.pix_chave <> ''),
    'cobra_sinal', (p.pix_chave <> '' and p.sinal_percentual > 0),
    'quartos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', q.id, 'nome', q.nome, 'tipo', q.tipo, 'capacidade', q.capacidade,
        'diaria', q.diaria, 'descricao', q.descricao, 'foto_url', q.foto_url) order by q.nome)
      from public.quartos q where q.pousada_id = p.id and q.ativo), '[]'::jsonb)
  ) end
  from public.pousadas p where p.slug = p_slug and p.ativo and p.situacao = 'aprovada';
$$;
revoke execute on function public.site_pousada(text) from public;
grant execute on function public.site_pousada(text) to anon, authenticated;

-- (2) limite por IP para a consulta de pedido
create table if not exists public.consulta_limite (ip text not null, slug text not null default '', em timestamptz not null default now());
alter table public.consulta_limite add column if not exists slug text not null default '';
create index if not exists consulta_limite_ip_em on public.consulta_limite (ip, em);
create index if not exists consulta_limite_slug_em on public.consulta_limite (slug, em);
revoke all on public.consulta_limite from anon, authenticated;

create or replace function public.consultar_pedido(p_slug text, p_codigo bigint, p_telefone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  v_ip text := coalesce(nullif(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1), ''), 'desconhecido');
  r jsonb;
begin
  -- teto contra força bruta: 15 falhas/min por IP e 120 falhas/min por pousada (segura IPs rotativos)
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
      'status', case when x.status = 'aguardando_pagamento' and x.criado_em < now() - interval '24 hours' then 'expirada' else x.status end,
      'nome', split_part(trim(x.nome), ' ', 1),
      'quarto', q.nome, 'entrada', x.entrada, 'saida', x.saida, 'adultos', x.adultos, 'criancas', x.criancas,
      'valor_total', case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end,
      'sinal_pago', x.sinal_pago, 'criado_em', x.criado_em,
      'sinal_exigido', public.sinal_exigido(x.pousada_id, case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end),
      'expira_em', x.criado_em + interval '24 hours',
      'pix_chave', (select pix_chave from public.pousadas where id = x.pousada_id))
    into r
    from public.reservas x
    join public.pousadas p on p.id = x.pousada_id and p.slug = p_slug and p.ativo and p.situacao = 'aprovada'
    join public.quartos q on q.id = x.quarto_id
   where x.codigo = p_codigo and right(regexp_replace(x.telefone, '\D', '', 'g'), 8) = right(tel, 8);

  if r is null then
    insert into public.consulta_limite (ip, slug) values (v_ip, p_slug);  -- penaliza só a falha
  end if;
  return r;
end $$;
revoke execute on function public.consultar_pedido(text, bigint, text) from public;
grant execute on function public.consultar_pedido(text, bigint, text) to anon, authenticated;
