-- =====================================================================
--  Migrazione v112 — Allegato OFFERTA FORNITORE su righe preventivo/commessa
--  Permette di caricare il file dell'offerta (PDF/email/immagine) del
--  fornitore che ha fatto il prezzo, e riaprirlo dalla riga.
--  File su Supabase Storage (bucket privato), riferimento salvato sulla riga.
--  Additiva e reversibile.
-- =====================================================================

-- 1) Colonne: percorso del file nello storage + nome originale (per mostrarlo)
alter table public.preventivi_righe
  add column if not exists fornitore_prezzo_allegato      text,
  add column if not exists fornitore_prezzo_allegato_nome text;

alter table public.commesse_righe
  add column if not exists fornitore_prezzo_allegato      text,
  add column if not exists fornitore_prezzo_allegato_nome text;

-- 2) Bucket privato per le offerte dei fornitori
insert into storage.buckets (id, name, public)
values ('offerte-fornitori','offerte-fornitori', false)
on conflict (id) do nothing;

-- 3) Permessi: solo utenti autenticati, solo su questo bucket
drop policy if exists "offerte_sel" on storage.objects;
drop policy if exists "offerte_ins" on storage.objects;
drop policy if exists "offerte_upd" on storage.objects;
drop policy if exists "offerte_del" on storage.objects;
create policy "offerte_sel" on storage.objects for select to authenticated
  using (bucket_id = 'offerte-fornitori');
create policy "offerte_ins" on storage.objects for insert to authenticated
  with check (bucket_id = 'offerte-fornitori');
create policy "offerte_upd" on storage.objects for update to authenticated
  using (bucket_id = 'offerte-fornitori') with check (bucket_id = 'offerte-fornitori');
create policy "offerte_del" on storage.objects for delete to authenticated
  using (bucket_id = 'offerte-fornitori');

-- Fine migrazione v112.
-- (Per annullare:
--   drop policy if exists "offerte_sel" on storage.objects; (idem ins/upd/del)
--   delete from storage.buckets where id='offerte-fornitori';  -- svuota prima il bucket
--   alter table public.preventivi_righe drop column fornitore_prezzo_allegato, drop column fornitore_prezzo_allegato_nome;
--   alter table public.commesse_righe  drop column fornitore_prezzo_allegato, drop column fornitore_prezzo_allegato_nome;)
