-- v21: nova regra das crianças na cobrança por pessoa:
--   até 4 anos não paga · de 5 a 12 anos paga 50% · 13 anos ou mais paga inteira, como adulto.
-- "pagantes" passa a ser número com fração (ex.: 2 adultos + 1 criança de 8 anos = 2,5).
drop function if exists public.quartos_disponiveis(text, date, date, int, int[]);
drop function if exists public.pagantes(uuid, int, int, int[]);

create function public.pagantes(p_pousada uuid, p_adultos int, p_criancas int, p_idades int[])
returns numeric language sql stable security definer set search_path = public as $$
  select case when (select cobranca from public.pousadas where id = p_pousada) = 'pessoa'
    then greatest(1, coalesce(p_adultos, 1)
      + (select coalesce(sum(case when i <= 4 then 0 when i <= 12 then 0.5 else 1 end), 0) from unnest(coalesce(p_idades, '{}')) i)
      -- criança sem idade informada (ex.: lançada no balcão) conta como inteira
      + greatest(0, coalesce(p_criancas, 0) - cardinality(coalesce(p_idades, '{}'))))
    else 1 end::numeric;
$$;
revoke execute on function public.pagantes(uuid, int, int, int[]) from public, anon, authenticated;

create function public.quartos_disponiveis(p_slug text, p_entrada date, p_saida date, p_adultos int, p_idades int[])
returns table(id uuid, nome text, tipo text, capacidade integer, diaria numeric, descricao text, foto_url text, noites integer, pagantes numeric, total numeric)
language plpgsql stable security definer set search_path = public as $$
declare pid uuid; n numeric;
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
    select q.id, q.nome, q.tipo, q.capacidade, q.diaria, q.descricao, q.foto_url, (p_saida - p_entrada)::int, n, round((p_saida - p_entrada) * q.diaria * n, 2)
    from public.quartos q
    where q.pousada_id = pid and q.ativo
      and not exists (select 1 from public.reservas r where r.quarto_id = q.id and r.status in ('confirmada', 'hospedado') and daterange(r.entrada, r.saida) && daterange(p_entrada, p_saida))
    order by q.diaria, q.nome;
end $$;
revoke execute on function public.quartos_disponiveis(text, date, date, int, int[]) from public;
grant execute on function public.quartos_disponiveis(text, date, date, int, int[]) to anon, authenticated;
