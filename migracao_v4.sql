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
