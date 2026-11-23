-- v15: tema editável por pousada (cores e desenho), escolhido pelo dono no painel.
-- Guarda só 4 chaves: principal, apoio e escuro (cores #rrggbb) e motivo (nenhum, guara ou pinheiro).
-- Vazio ({}) = cores padrão (azul-marinho e laranja). O site lê pela função site_pousada.
alter table public.pousadas add column if not exists tema jsonb not null default '{}'::jsonb;
alter table public.pousadas drop constraint if exists pousadas_tema_ok;
alter table public.pousadas add constraint pousadas_tema_ok check (
  jsonb_typeof(tema) = 'object'
  and (tema - 'principal' - 'apoio' - 'escuro' - 'motivo') = '{}'::jsonb
  and (not tema ? 'principal' or tema->>'principal' ~ '^#[0-9a-fA-F]{6}$')
  and (not tema ? 'apoio' or tema->>'apoio' ~ '^#[0-9a-fA-F]{6}$')
  and (not tema ? 'escuro' or tema->>'escuro' ~ '^#[0-9a-fA-F]{6}$')
  and (not tema ? 'motivo' or tema->>'motivo' in ('nenhum', 'guara', 'pinheiro'))
);
grant select (tema), update (tema) on public.pousadas to authenticated;  -- a política "dono edita" já limita a quem é dono

-- o site lê o tema junto com os demais dados da pousada
CREATE OR REPLACE FUNCTION public.site_pousada(p_slug text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when p.id is null then null else jsonb_build_object(
    'slug', p.slug, 'nome', p.nome, 'cidade', p.cidade, 'bairro', p.bairro,
    'descricao', p.descricao, 'whatsapp', p.whatsapp, 'email', p.email, 'instagram', p.instagram,
    'checkin_hora', p.checkin_hora, 'checkout_hora', p.checkout_hora, 'acesso', p.acesso,
    'como_chegar', p.como_chegar, 'pagamentos', p.pagamentos, 'sinal_percentual', p.sinal_percentual,
    'politica', p.politica, 'fotos', p.fotos, 'tema', p.tema,
    'aceita_pix', (p.pix_chave <> ''),
    'cobra_sinal', (p.pix_chave <> '' and p.sinal_percentual > 0),
    'quartos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', q.id, 'nome', q.nome, 'tipo', q.tipo, 'capacidade', q.capacidade,
        'diaria', q.diaria, 'descricao', q.descricao, 'foto_url', q.foto_url) order by q.nome)
      from public.quartos q where q.pousada_id = p.id and q.ativo), '[]'::jsonb)
  ) end
  from public.pousadas p where p.slug = p_slug and p.ativo and p.situacao = 'aprovada';
$function$;

-- Pousada Guará: as cores do logo
update public.pousadas set tema = '{"principal": "#ff2400", "apoio": "#5a3b2c", "escuro": "#1d1512", "motivo": "guara"}'::jsonb where slug = 'pousada-exemplo';
