-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v5  (accesso staff agli ordini e-commerce)
--
--  COSA FA (tutto ADDITIVO): apre in LETTURA agli utenti staff del gestionale
--  (ruoli con accesso commesse) gli ordini del negozio, le righe e i file
--  caricati dai clienti, per il pannello "Ordini Komunigo". Consente allo staff
--  (amministratore/commerciale) di aggiornare lo STATO di ordine e file.
--
--  La creazione degli ordini resta SOLO lato server (Edge Function): qui non
--  si aggiungono policy di INSERT/DELETE per gli utenti.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---- ordini: lettura staff + aggiornamento stato ----
drop policy if exists komunigo_ordini_staff_sel on public.komunigo_ordini;
create policy komunigo_ordini_staff_sel on public.komunigo_ordini for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

drop policy if exists komunigo_ordini_staff_upd on public.komunigo_ordini;
create policy komunigo_ordini_staff_upd on public.komunigo_ordini for update to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---- righe: lettura staff ----
drop policy if exists komunigo_righe_staff_sel on public.komunigo_ordini_righe;
create policy komunigo_righe_staff_sel on public.komunigo_ordini_righe for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

-- ---- file: lettura staff (ricreata con 4 ruoli) + aggiornamento stato ----
drop policy if exists komunigo_ordini_file_staff on public.komunigo_ordini_file;
create policy komunigo_ordini_file_staff on public.komunigo_ordini_file for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

drop policy if exists komunigo_file_staff_upd on public.komunigo_ordini_file;
create policy komunigo_file_staff_upd on public.komunigo_ordini_file for update to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---- storage bucket komunigo-ordini: lettura/scarico staff (ricreata con 4 ruoli) ----
drop policy if exists komunigo_ordini_files_staff on storage.objects;
create policy komunigo_ordini_files_staff on storage.objects for select to authenticated
  using (bucket_id = 'komunigo-ordini'
         and public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

-- Fine migrazione Komunigo v5.
