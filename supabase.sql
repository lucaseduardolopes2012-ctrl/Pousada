-- Gestão de pousada: banco de dados (Supabase / Postgres)
-- Cada pousada só enxerga os próprios dados. Pode rodar de novo sem quebrar.

create extension if not exists btree_gist;

create or replace function public.hoje_br() returns date
language sql stable as $$ select (now() at time zone 'America/Sao_Paulo')::date $$;

-- ---------- tabelas ----------
create table if not exists public.pousadas (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,40}$'),
  nome text not null check (length(trim(nome)) between 2 and 80),
  cidade text not null default '' check (length(cidade) <= 80),
  descricao text not null default '' check (length(descricao) <= 1200),
  whatsapp text not null default '' check (length(whatsapp) <= 20),
  email text not null default '' check (length(email) <= 120),
  endereco text not null default '' check (length(endereco) <= 200),
  checkin_hora text not null default '14:00' check (checkin_hora ~ '^[0-2][0-9]:[0-5][0-9]$'),
  checkout_hora text not null default '12:00' check (checkout_hora ~ '^[0-2][0-9]:[0-5][0-9]$'),
  cor text not null default '#1f6f5c' check (cor ~ '^#[0-9a-fA-F]{6}$'),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists public.membros (
  pousada_id uuid not null references public.pousadas on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  papel text not null check (papel in ('dono', 'recepcao')),
  primary key (pousada_id, user_id)
);

create table if not exists public.quartos (
  id uuid primary key default gen_random_uuid(),
  pousada_id uuid not null references public.pousadas on delete cascade,
  nome text not null check (length(trim(nome)) between 1 and 60),
  tipo text not null default '' check (length(tipo) <= 40),
  capacidade int not null default 2 check (capacidade between 1 and 20),
  diaria numeric(10, 2) not null check (diaria >= 0 and diaria < 100000),
  descricao text not null default '' check (length(descricao) <= 500),
  foto_url text check (foto_url is null or foto_url ~ '^https://'),
  ativo boolean not null default true,
  unique (id, pousada_id)
);

create table if not exists public.reservas (
  id uuid primary key default gen_random_uuid(),
  codigo bigint generated always as identity,
  pousada_id uuid not null,
  quarto_id uuid not null,
  nome text not null check (length(trim(nome)) between 1 and 100),
  telefone text not null default '' check (length(telefone) <= 20),
  email text not null default '' check (length(email) <= 120),
  documento text not null default '' check (length(documento) <= 30),
  adultos int not null default 1 check (adultos between 1 and 20),
  criancas int not null default 0 check (criancas between 0 and 20),
  entrada date not null,
  saida date not null,
  status text not null default 'solicitada' check (status in ('solicitada', 'confirmada', 'hospedado', 'finalizada', 'cancelada', 'no_show')),
  origem text not null default 'balcao' check (origem in ('site', 'balcao', 'telefone', 'whatsapp', 'booking', 'outro')),
  valor_total numeric(10, 2) not null default 0 check (valor_total >= 0),
  sinal_pago numeric(10, 2) not null default 0 check (sinal_pago >= 0),
  observacoes text not null default '' check (length(observacoes) <= 500),
  criado_em timestamptz not null default now(),
  foreign key (quarto_id, pousada_id) references public.quartos (id, pousada_id),
  check (saida > entrada),
  check (saida - entrada <= 90),
  exclude using gist (quarto_id with =, daterange(entrada, saida) with &&) where (status in ('confirmada', 'hospedado'))
);
create index if not exists reservas_pousada_idx on public.reservas (pousada_id, entrada);
create index if not exists reservas_status_idx on public.reservas (pousada_id, status);

-- valor automático (noites x diária) quando não informado
create or replace function public.reservas_antes_de_gravar() returns trigger
language plpgsql security definer set search_path = public as $$
declare d numeric;
begin
  if tg_op = 'INSERT' and coalesce(new.valor_total, 0) = 0 then
    select diaria into d from public.quartos where id = new.quarto_id;
    new.valor_total := coalesce(d, 0) * (new.saida - new.entrada);
  end if;
  return new;
end $$;
drop trigger if exists reservas_antes_de_gravar on public.reservas;
create trigger reservas_antes_de_gravar before insert on public.reservas
  for each row execute function public.reservas_antes_de_gravar();

-- ---------- quem é de qual pousada ----------
create or replace function public.is_membro(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.membros where pousada_id = p and user_id = auth.uid())
$$;
create or replace function public.is_dono(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.membros where pousada_id = p and user_id = auth.uid() and papel = 'dono')
$$;
revoke execute on function public.is_membro(uuid), public.is_dono(uuid) from public, anon;
grant execute on function public.is_membro(uuid), public.is_dono(uuid) to authenticated;

-- ---------- acesso ----------
alter table public.pousadas enable row level security;
alter table public.membros enable row level security;
alter table public.quartos enable row level security;
alter table public.reservas enable row level security;

revoke all on public.pousadas, public.membros, public.quartos, public.reservas from anon, authenticated;

grant select (id, slug, nome, cidade, descricao, whatsapp, email, endereco, checkin_hora, checkout_hora, cor, ativo) on public.pousadas to anon, authenticated;
grant update (nome, cidade, descricao, whatsapp, email, endereco, checkin_hora, checkout_hora, cor) on public.pousadas to authenticated;
grant select (id, pousada_id, nome, tipo, capacidade, diaria, descricao, foto_url, ativo) on public.quartos to anon, authenticated;
grant insert (pousada_id, nome, tipo, capacidade, diaria, descricao, foto_url, ativo), update (nome, tipo, capacidade, diaria, descricao, foto_url, ativo), delete on public.quartos to authenticated;
grant select on public.membros to authenticated;
grant select, delete on public.reservas to authenticated;
grant insert (pousada_id, quarto_id, nome, telefone, email, documento, adultos, criancas, entrada, saida, status, origem, valor_total, sinal_pago, observacoes) on public.reservas to authenticated;
grant update (quarto_id, nome, telefone, email, documento, adultos, criancas, entrada, saida, status, origem, valor_total, sinal_pago, observacoes) on public.reservas to authenticated;

drop policy if exists "pousadas: publico le as ativas" on public.pousadas;
drop policy if exists "pousadas: visitante le as ativas" on public.pousadas;
create policy "pousadas: visitante le as ativas" on public.pousadas for select to anon using (ativo);
drop policy if exists "pousadas: logado le as ativas ou a sua" on public.pousadas;
create policy "pousadas: logado le as ativas ou a sua" on public.pousadas for select to authenticated using (ativo or public.is_membro(id));
drop policy if exists "pousadas: dono edita" on public.pousadas;
create policy "pousadas: dono edita" on public.pousadas for update to authenticated using (public.is_dono(id)) with check (public.is_dono(id));

drop policy if exists "membros: ve o proprio, dono ve a equipe" on public.membros;
create policy "membros: ve o proprio, dono ve a equipe" on public.membros for select to authenticated using (user_id = auth.uid() or public.is_dono(pousada_id));

drop policy if exists "quartos: publico le os ativos" on public.quartos;
drop policy if exists "quartos: visitante le os ativos" on public.quartos;
create policy "quartos: visitante le os ativos" on public.quartos for select to anon using (ativo and exists (select 1 from public.pousadas p where p.id = pousada_id and p.ativo));
drop policy if exists "quartos: logado le" on public.quartos;
create policy "quartos: logado le" on public.quartos for select to authenticated using (ativo or public.is_membro(pousada_id));
drop policy if exists "quartos: dono cria" on public.quartos;
create policy "quartos: dono cria" on public.quartos for insert to authenticated with check (public.is_dono(pousada_id));
drop policy if exists "quartos: dono edita" on public.quartos;
create policy "quartos: dono edita" on public.quartos for update to authenticated using (public.is_dono(pousada_id)) with check (public.is_dono(pousada_id));
drop policy if exists "quartos: dono apaga" on public.quartos;
create policy "quartos: dono apaga" on public.quartos for delete to authenticated using (public.is_dono(pousada_id));

drop policy if exists "reservas: equipe ve" on public.reservas;
create policy "reservas: equipe ve" on public.reservas for select to authenticated using (public.is_membro(pousada_id));
drop policy if exists "reservas: equipe cria" on public.reservas;
create policy "reservas: equipe cria" on public.reservas for insert to authenticated with check (public.is_membro(pousada_id));
drop policy if exists "reservas: equipe edita" on public.reservas;
create policy "reservas: equipe edita" on public.reservas for update to authenticated using (public.is_membro(pousada_id)) with check (public.is_membro(pousada_id));
drop policy if exists "reservas: dono apaga" on public.reservas;
create policy "reservas: dono apaga" on public.reservas for delete to authenticated using (public.is_dono(pousada_id));

-- ---------- funções públicas do site ----------
create or replace function public.quartos_disponiveis(p_slug text, p_entrada date, p_saida date)
returns table (id uuid, nome text, tipo text, capacidade int, diaria numeric, descricao text, foto_url text, noites int, total numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then
    raise exception 'Escolha datas válidas: a saída depois da entrada e a entrada a partir de hoje.';
  end if;
  return query
    select q.id, q.nome, q.tipo, q.capacidade, q.diaria, q.descricao, q.foto_url, (p_saida - p_entrada)::int, ((p_saida - p_entrada) * q.diaria)::numeric
    from public.quartos q join public.pousadas p on p.id = q.pousada_id
    where p.slug = p_slug and p.ativo and q.ativo
      and not exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida))
    order by q.diaria, q.nome;
end $$;

create or replace function public.solicitar_reserva(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos int, p_criancas int, p_nome text, p_telefone text, p_email text, p_obs text)
returns bigint language plpgsql security definer set search_path = public as $$
declare pid uuid; q public.quartos; tel text; cod bigint; ativos int; da_pousada int;
begin
  if p_entrada is null or p_saida is null or p_saida <= p_entrada or p_saida - p_entrada > 60 or p_entrada < public.hoje_br() then
    raise exception 'Escolha datas válidas.';
  end if;
  if length(trim(coalesce(p_nome, ''))) < 2 or length(p_nome) > 100 then raise exception 'Informe seu nome.'; end if;
  tel := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g');
  if length(tel) < 10 or length(tel) > 13 then raise exception 'Informe um telefone com DDD.'; end if;
  if length(coalesce(p_email, '')) > 120 or length(coalesce(p_obs, '')) > 500 then raise exception 'Texto muito longo.'; end if;
  if coalesce(p_adultos, 0) < 1 or coalesce(p_criancas, 0) < 0 or p_adultos > 20 or p_criancas > 20 then raise exception 'Quantidade de hóspedes inválida.'; end if;
  select id into pid from public.pousadas where slug = p_slug and ativo;
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

revoke execute on function public.quartos_disponiveis(text, date, date), public.solicitar_reserva(text, uuid, date, date, int, int, text, text, text, text) from public;
grant execute on function public.quartos_disponiveis(text, date, date), public.solicitar_reserva(text, uuid, date, date, int, int, text, text, text, text) to anon, authenticated;
revoke execute on function public.hoje_br(), public.reservas_antes_de_gravar() from public, anon, authenticated;

-- ---------- tempo real ----------
do $$ begin
  alter publication supabase_realtime add table public.reservas;
exception when duplicate_object then null; end $$;

-- ---------- pousada de demonstração (sem reservas) ----------
insert into public.pousadas (slug, nome, cidade, descricao, cor)
values ('pousada-exemplo', 'Pousada Exemplo', 'Guaraqueçaba, PR', 'Texto de exemplo. Aqui vai a apresentação da pousada: localização, ambiente, café da manhã e passeios próximos.', '#1f6f5c')
on conflict (slug) do nothing;
insert into public.quartos (pousada_id, nome, tipo, capacidade, diaria, descricao)
select p.id, v.nome, v.tipo, v.cap, v.diaria, v.descr from public.pousadas p,
  (values ('Quarto 1', 'Casal', 2, 180.00, 'Cama de casal e banheiro privativo.'),
          ('Quarto 2', 'Família', 4, 280.00, 'Uma cama de casal e duas de solteiro.'),
          ('Chalé', 'Chalé', 3, 240.00, 'Chalé com varanda.')) as v(nome, tipo, cap, diaria, descr)
where p.slug = 'pousada-exemplo' and not exists (select 1 from public.quartos q where q.pousada_id = p.id);
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
-- v4: fotos dos quartos (cada pousada só envia/apaga na própria pasta)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "fotos: membro envia" on storage.objects;
create policy "fotos: membro envia" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] in (select pousada_id::text from public.membros where user_id = auth.uid()));
drop policy if exists "fotos: membro troca" on storage.objects;
create policy "fotos: membro troca" on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] in (select pousada_id::text from public.membros where user_id = auth.uid()));
drop policy if exists "fotos: membro apaga" on storage.objects;
create policy "fotos: membro apaga" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] in (select pousada_id::text from public.membros where user_id = auth.uid()));
