-- v20: a chave do Firebase fica criptografada no Vault (nome 'fcm_conta'); só a service_role lê.
-- Gravar/trocar a chave: select vault.create_secret('<json>', 'fcm_conta')  /  vault.update_secret(id, '<json>')
create or replace function public.fcm_conta()
returns text language sql stable security definer set search_path = public, vault as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'fcm_conta' limit 1;
$$;
revoke execute on function public.fcm_conta() from public, anon, authenticated;
grant execute on function public.fcm_conta() to service_role;
