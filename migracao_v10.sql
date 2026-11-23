-- v10: o hóspede acompanha o pedido numa página (reserva.html).
-- Consulta pública e segura: só devolve o pedido quando o número e o telefone usados nele batem
-- (últimos 8 dígitos), para ninguém conseguir ver pedidos dos outros adivinhando números.
-- Devolve só o necessário para o hóspede (primeiro nome, datas, quarto, estado e valores).
create or replace function public.consultar_pedido(p_slug text, p_codigo bigint, p_telefone text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare tel text := regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g'); r jsonb;
begin
  if p_codigo is null or p_codigo < 1 or length(tel) < 10 or length(tel) > 13 then
    perform pg_sleep(0.4); return null;
  end if;
  select jsonb_build_object(
      'codigo', x.codigo, 'status', x.status, 'nome', split_part(trim(x.nome), ' ', 1),
      'quarto', q.nome, 'entrada', x.entrada, 'saida', x.saida, 'adultos', x.adultos, 'criancas', x.criancas,
      'valor_total', case when x.valor_total > 0 then x.valor_total else q.diaria * (x.saida - x.entrada) end,
      'sinal_pago', x.sinal_pago, 'criado_em', x.criado_em)
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
