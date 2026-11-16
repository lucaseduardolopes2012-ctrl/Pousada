-- v2: informações da pousada coletadas no cadastro guiado + criação pelo próprio dono
alter table public.pousadas
  add column if not exists bairro text not null default '' check (length(bairro) <= 80),
  add column if not exists acesso text not null default 'estrada' check (acesso in ('estrada', 'barco', 'ambos')),
  add column if not exists como_chegar text not null default '' check (length(como_chegar) <= 600),
  add column if not exists comodidades text[] not null default '{}' check (cardinality(comodidades) <= 20 and length(array_to_string(comodidades, ',')) <= 700),
  add column if not exists pagamentos text[] not null default '{}' check (cardinality(pagamentos) <= 8 and length(array_to_string(pagamentos, ',')) <= 200),
  add column if not exists sinal_percentual int not null default 0 check (sinal_percentual between 0 and 100),
  add column if not exists politica text not null default '' check (length(politica) <= 800),
  add column if not exists instagram text not null default '' check (length(instagram) <= 40);

grant select (bairro, acesso, como_chegar, comodidades, pagamentos, sinal_percentual, politica, instagram) on public.pousadas to anon, authenticated;
grant update (bairro, acesso, como_chegar, comodidades, pagamentos, sinal_percentual, politica, instagram) on public.pousadas to authenticated;

-- o dono cria a própria pousada (uma por conta), já com os quartos
create or replace function public.criar_minha_pousada(p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); base text; s text; n int := 0; pid uuid; q jsonb;
begin
  if uid is null then raise exception 'Entre na sua conta primeiro.'; end if;
  if exists (select 1 from public.membros where user_id = uid) then raise exception 'Sua conta já tem uma pousada cadastrada.'; end if;
  if length(trim(coalesce(p->>'nome', ''))) < 2 then raise exception 'Informe o nome da pousada.'; end if;
  if jsonb_typeof(p->'quartos') is distinct from 'array' or jsonb_array_length(p->'quartos') = 0 or jsonb_array_length(p->'quartos') > 30 then
    raise exception 'Cadastre de 1 a 30 quartos.';
  end if;
  base := lower(translate(trim(p->>'nome'), 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑáàâãäéèêëíìîïóòôõöúùûüçñ', 'AAAAAEEEEIIIIOOOOOUUUUCNaaaaaeeeeiiiiooooouuuucn'));
  base := trim(both '-' from regexp_replace(base, '[^a-z0-9]+', '-', 'g'));
  base := left(base, 32);
  if length(base) < 3 then base := 'pousada'; end if;
  s := base;
  while exists (select 1 from public.pousadas where slug = s) loop n := n + 1; s := base || '-' || n; end loop;
  insert into public.pousadas (slug, nome, cidade, bairro, acesso, como_chegar, descricao, whatsapp, email, instagram, checkin_hora, checkout_hora, cor, comodidades, pagamentos, sinal_percentual, politica)
  values (s, trim(p->>'nome'), trim(coalesce(p->>'cidade', '')), trim(coalesce(p->>'bairro', '')), coalesce(nullif(p->>'acesso', ''), 'estrada'), trim(coalesce(p->>'como_chegar', '')),
          trim(coalesce(p->>'descricao', '')), regexp_replace(coalesce(p->>'whatsapp', ''), '\D', '', 'g'), trim(coalesce(p->>'email', '')), trim(both '@ ' from coalesce(p->>'instagram', '')),
          coalesce(nullif(p->>'checkin_hora', ''), '14:00'), coalesce(nullif(p->>'checkout_hora', ''), '12:00'), coalesce(nullif(p->>'cor', ''), '#0e6e6a'),
          coalesce(array(select left(trim(x), 40) from jsonb_array_elements_text(coalesce(p->'comodidades', '[]')) x where trim(x) <> '' limit 20), '{}'),
          coalesce(array(select left(trim(x), 30) from jsonb_array_elements_text(coalesce(p->'pagamentos', '[]')) x where trim(x) <> '' limit 8), '{}'),
          coalesce((p->>'sinal_percentual')::int, 0), trim(coalesce(p->>'politica', '')))
  returning id into pid;
  insert into public.membros (pousada_id, user_id, papel) values (pid, uid, 'dono');
  for q in select value from jsonb_array_elements(p->'quartos') loop
    insert into public.quartos (pousada_id, nome, tipo, capacidade, diaria, descricao)
    values (pid, trim(coalesce(q->>'nome', '')), trim(coalesce(q->>'tipo', '')), coalesce((q->>'capacidade')::int, 2), coalesce((q->>'diaria')::numeric, 0), trim(coalesce(q->>'descricao', '')));
  end loop;
  return s;
end $$;
revoke execute on function public.criar_minha_pousada(jsonb) from public, anon;
grant execute on function public.criar_minha_pousada(jsonb) to authenticated;

update public.pousadas set cor = '#0e6e6a', bairro = 'Centro', acesso = 'ambos',
  comodidades = '{"Café da manhã incluso","Wi-Fi","Roupa de cama e banho","Passeios de barco"}', pagamentos = '{"Pix","Cartão de crédito","Dinheiro"}', sinal_percentual = 30,
  como_chegar = 'Texto de exemplo: pela estrada até o centro, ou de barco saindo de Paranaguá.'
where slug = 'pousada-exemplo';
