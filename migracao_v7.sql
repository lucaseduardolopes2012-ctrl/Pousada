-- v7: fotos da pousada (fachada, áreas comuns, vista) para a galeria do site. A primeira é a capa.
-- Os arquivos ficam no bucket "fotos", na pasta da própria pousada (regra da v4).
alter table public.pousadas
  add column if not exists fotos text[] not null default '{}'
  check (cardinality(fotos) <= 12 and array_to_string(fotos, ' ') !~ '(^| )(?!https://)\S');
grant select (fotos) on public.pousadas to anon, authenticated;
grant update (fotos) on public.pousadas to authenticated;
