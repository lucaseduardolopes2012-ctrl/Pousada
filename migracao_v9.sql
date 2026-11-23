-- v9: pagamento por Pix.
-- O dono guarda a chave Pix da pousada (painel > Configurações) e o site monta o QR code
-- com ela no navegador do hóspede (padrão "Pix copia e cola" estático). O Pix cai direto na
-- conta do dono; o sistema não intermedeia nem confirma o pagamento sozinho.
alter table public.pousadas
  add column if not exists pix_chave text not null default '' check (length(pix_chave) <= 77);

-- só o dono logado (RLS) lê e muda a chave pelo painel; o público a recebe pela função abaixo.
grant select (pix_chave), update (pix_chave) on public.pousadas to authenticated;

create or replace function public.site_pousada(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when p.id is null then null else jsonb_build_object(
    'slug', p.slug, 'nome', p.nome, 'cidade', p.cidade, 'bairro', p.bairro,
    'descricao', p.descricao, 'whatsapp', p.whatsapp, 'email', p.email, 'instagram', p.instagram,
    'checkin_hora', p.checkin_hora, 'checkout_hora', p.checkout_hora, 'acesso', p.acesso,
    'como_chegar', p.como_chegar, 'pagamentos', p.pagamentos, 'sinal_percentual', p.sinal_percentual,
    'politica', p.politica, 'fotos', p.fotos, 'pix_chave', p.pix_chave,
    'quartos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', q.id, 'nome', q.nome, 'tipo', q.tipo, 'capacidade', q.capacidade,
        'diaria', q.diaria, 'descricao', q.descricao, 'foto_url', q.foto_url) order by q.nome)
      from public.quartos q where q.pousada_id = p.id and q.ativo), '[]'::jsonb)
  ) end
  from public.pousadas p where p.slug = p_slug and p.ativo and p.situacao = 'aprovada';
$$;
revoke execute on function public.site_pousada(text) from public;
grant execute on function public.site_pousada(text) to anon, authenticated;
