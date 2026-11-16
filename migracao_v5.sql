-- v5: site público da pousada com ficha do hóspede.
-- A aprovação manual de pousadas (v3) não é mais usada: toda pousada nova já aparece no site.
alter table public.pousadas alter column situacao set default 'aprovada';
update public.pousadas set situacao = 'aprovada', decidido_em = coalesce(decidido_em, now()) where situacao = 'pendente';

-- Pedido feito pelo hóspede no site, agora com documento (CPF/RG, útil para a ficha FNRH).
-- Reaproveita solicitar_reserva (validações de datas, telefone, capacidade, conflito e limites contra pedidos em massa).
create or replace function public.pedir_estadia(p_slug text, p_quarto uuid, p_entrada date, p_saida date, p_adultos int, p_criancas int,
  p_nome text, p_telefone text, p_documento text, p_email text, p_obs text)
returns bigint language plpgsql security definer set search_path = public as $$
declare cod bigint; doc text := trim(coalesce(p_documento, ''));
begin
  if length(doc) > 30 then raise exception 'Documento muito longo.'; end if;
  if coalesce(p_email, '') <> '' and p_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Esse email não parece completo.'; end if;
  cod := public.solicitar_reserva(p_slug, p_quarto, p_entrada, p_saida, p_adultos, p_criancas, p_nome, p_telefone, p_email, p_obs);
  if doc <> '' then update public.reservas set documento = doc where codigo = cod; end if;
  return cod;
end $$;
revoke execute on function public.pedir_estadia(text, uuid, date, date, int, int, text, text, text, text, text) from public;
grant execute on function public.pedir_estadia(text, uuid, date, date, int, int, text, text, text, text, text) to anon, authenticated;
