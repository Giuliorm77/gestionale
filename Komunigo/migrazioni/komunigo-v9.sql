-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v9  (bozza grafica da approvare)
--
--  COSA FA (tutto ADDITIVO):
--   1) komunigo_ordini.bozza_stato: stato della bozza/simulazione di stampa
--      (null = nessuna, 'da_approvare', 'approvata', 'modifiche_richieste').
--   2) komunigo_ordini.bozza_feedback: eventuali modifiche chieste dal cliente.
--   3) komunigo_ordini_file.tipo: 'cliente' (file caricato dal cliente) oppure
--      'bozza' (simulazione caricata dallo staff).
--   4) Policy: lo staff (amministratore/commerciale) può caricare/gestire i file
--      (bozze) e i relativi oggetti nel bucket privato komunigo-ordini.
--
--  Il cliente approva/chiede modifiche tramite la Edge Function (col token):
--  qui NON si aprono permessi anon.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.komunigo_ordini
  add column if not exists bozza_stato    text,
  add column if not exists bozza_feedback text;

alter table public.komunigo_ordini_file
  add column if not exists tipo text not null default 'cliente';

do $$ begin
  if not exists (select 1 from pg_constraint where conname='komunigo_ordini_file_tipo_chk') then
    alter table public.komunigo_ordini_file
      add constraint komunigo_ordini_file_tipo_chk check (tipo in ('cliente','bozza'));
  end if;
end $$;

-- Lo staff (amministratore/commerciale) gestisce i file (carica le bozze).
-- La SELECT resta com'era (staff 4 ruoli, dalla v5); qui aggiungiamo INS/UPD/DEL.
drop policy if exists komunigo_ordini_file_write on public.komunigo_ordini_file;
create policy komunigo_ordini_file_write on public.komunigo_ordini_file for all to authenticated
  using      (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Bucket privato komunigo-ordini: lo staff può caricare/eliminare le bozze.
drop policy if exists komunigo_ordini_files_write on storage.objects;
create policy komunigo_ordini_files_write on storage.objects for all to authenticated
  using      (bucket_id = 'komunigo-ordini' and public.ruolo_utente() in ('amministratore','commerciale'))
  with check (bucket_id = 'komunigo-ordini' and public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione Komunigo v9.
