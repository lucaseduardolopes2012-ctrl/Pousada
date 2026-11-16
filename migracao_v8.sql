-- v8 (segurança, pós-pentest):
--  (2) impede enumerar todas as pousadas: o site passa a ler UMA pousada por slug via função,
--      e o visitante anônimo perde o SELECT direto em pousadas e quartos.
--  (4) aperta o limite contra pedidos falsos em massa.

-- ---- (2) função pública que devolve só a pousada do slug + seus quartos ativos ----
create or replace function public.site_pousada(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when p.id is null then null else jsonb_build_object(
    'slug', p.slug, 'nome', p.nome, 'cidade', p.cidade, 'bairro', p.bairro,
    'descricao', p.descricao, 'whatsapp', p.whatsapp, 'email', p.email, 'instagram', p.instagram,
    'checkin_hora', p.checkin_hora, 'checkout_hora', p.checkout_hora, 'acesso', p.acesso,
    'como_chegar', p.como_chegar, 'pagamentos', p.pagamentos, 'sinal_percentual', p.sinal_percentual,
    'politica', p.politica, 'fotos', p.fotos,
    'quartos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', q.id, 'nome', q.nome, 'tipo', q.tipo, 'capacidade', q.capacidade,
        'diaria', q.diaria, 'descricao', q.descricao, 'foto_url', q.foto_url) order by q.nome)
      from public.quartos q where q.pousada_id = p.id and q.ativo), '[]'::jsonb)
  ) end
  from public.pousadas p where p.slug = p_slug and p.ativo and p.situacao = 'aprovada';
$$;
revoke execute on function public.site_pousada(text) from public;
grant execute on function public.site_pousada(text) to anon, authenticated;

-- o visitante não lê mais as tabelas direto; só o dono logado (RLS) e as funções acima.
revoke select on public.pousadas from anon;
revoke select on public.quartos from anon;

-- ---- (4) limite mais apertado contra pedidos falsos ----
create or replace function public.solicitar_reserva(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos int, p_criancas int, p_nome text, p_telefone text, p_email text, p_obs text)
returns bigint language plpgsql security definer set search_path = public as $$
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
  if exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida)) then
    raise exception 'Esse quarto acabou de ficar indisponível nessas datas.';
  end if;
  select count(*) into por_hora from public.reservas where pousada_id = pid and status = 'solicitada' and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '1 hour';
  if por_hora >= 3 then raise exception 'Você já enviou pedidos recentemente. Aguarde a resposta da pousada.'; end if;
  select count(*) into por_dia from public.reservas where pousada_id = pid and status = 'solicitada' and regexp_replace(telefone, '\D', '', 'g') = tel and criado_em > now() - interval '24 hours';
  if por_dia >= 6 then raise exception 'Muitos pedidos deste telefone hoje. Fale direto com a pousada.'; end if;
  select count(*) into da_pousada from public.reservas where pousada_id = pid and status = 'solicitada' and criado_em > now() - interval '1 hour';
  if da_pousada >= 20 then raise exception 'Muitos pedidos agora. Tente de novo mais tarde.'; end if;
  insert into public.reservas (pousada_id, quarto_id, nome, telefone, email, adultos, criancas, entrada, saida, status, origem, observacoes)
  values (pid, q.id, trim(p_nome), trim(p_telefone), trim(coalesce(p_email, '')), p_adultos, p_criancas, p_entrada, p_saida, 'solicitada', 'site', trim(coalesce(p_obs, '')))
  returning codigo into cod;
  return cod;
end $$;
revoke execute on function public.solicitar_reserva(text, uuid, date, date, int, int, text, text, text, text) from public, anon;
grant execute on function public.solicitar_reserva(text, uuid, date, date, int, int, text, text, text, text) to anon, authenticated;
