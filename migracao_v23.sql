-- v23: perguntas frequentes escritas pela pousada (o site junta com as automáticas)
alter table public.pousadas add column if not exists faq jsonb not null default '[]'::jsonb;
alter table public.pousadas drop constraint if exists pousadas_faq_ok;
alter table public.pousadas add constraint pousadas_faq_ok check (jsonb_typeof(faq) = 'array' and jsonb_array_length(faq) <= 15 and length(faq::text) <= 12000);
grant select (faq) on public.pousadas to authenticated;
grant update (faq) on public.pousadas to authenticated;
-- site_pousada passou a devolver 'faq' (definição completa aplicada no banco)
