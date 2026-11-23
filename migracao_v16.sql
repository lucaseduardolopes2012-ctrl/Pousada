-- v16: o tema ganha o "modelo" da página (o desenho inteiro: classico ou horadourada), além das cores e do motivo.
alter table public.pousadas drop constraint if exists pousadas_tema_ok;
alter table public.pousadas add constraint pousadas_tema_ok check (
  jsonb_typeof(tema) = 'object'
  and (tema - 'principal' - 'apoio' - 'escuro' - 'motivo' - 'modelo') = '{}'::jsonb
  and (not tema ? 'principal' or tema->>'principal' ~ '^#[0-9a-fA-F]{6}$')
  and (not tema ? 'apoio' or tema->>'apoio' ~ '^#[0-9a-fA-F]{6}$')
  and (not tema ? 'escuro' or tema->>'escuro' ~ '^#[0-9a-fA-F]{6}$')
  and (not tema ? 'motivo' or tema->>'motivo' in ('nenhum', 'guara', 'pinheiro'))
  and (not tema ? 'modelo' or tema->>'modelo' in ('classico', 'horadourada'))
);
