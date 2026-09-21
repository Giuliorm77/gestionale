-- =====================================================================
--  MIGRAZIONE v28 - Foto articolo (Storage) + flag "da ripristinare"
--
--  1) Archivio "articoli" nello Storage di Supabase (bucket pubblico) con
--     i permessi: chiunque puo' VEDERE le foto, solo gli utenti loggati
--     possono caricarle/eliminarle.
--  2) Nuovi campi sulla tabella articoli:
--     - foto_urls      : elenco dei link alle foto (piu' foto per articolo)
--     - da_ripristinare : spunta "c'e' qualcosa da sistemare"
--     - nota_ripristino : cosa c'e' da fare
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- 1) BUCKET / ARCHIVIO FOTO ------------------------------------------------
insert into storage.buckets (id, name, public)
values ('articoli','articoli', true)
on conflict (id) do nothing;

-- permessi sull'archivio (storage.objects ha gia' la RLS attiva)
drop policy if exists articoli_foto_read   on storage.objects;
drop policy if exists articoli_foto_insert on storage.objects;
drop policy if exists articoli_foto_update on storage.objects;
drop policy if exists articoli_foto_delete on storage.objects;

create policy articoli_foto_read   on storage.objects for select to public
  using (bucket_id = 'articoli');
create policy articoli_foto_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'articoli');
create policy articoli_foto_update on storage.objects for update to authenticated
  using (bucket_id = 'articoli');
create policy articoli_foto_delete on storage.objects for delete to authenticated
  using (bucket_id = 'articoli');

-- 2) CAMPI SULL'ARTICOLO ---------------------------------------------------
alter table public.articoli add column if not exists foto_urls       text[]  default '{}';
alter table public.articoli add column if not exists da_ripristinare boolean default false;
alter table public.articoli add column if not exists nota_ripristino text    default '';

-- Fine migrazione v28.
