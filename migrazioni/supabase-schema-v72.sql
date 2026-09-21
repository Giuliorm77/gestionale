-- =====================================================================
--  MIGRAZIONE v72 - DESCRIZIONE BREVE sul PREVENTIVO
--
--  Una riga di testo per riconoscere al volo il preventivo nell'elenco
--  (oltre a numero e cliente). Es. "Stampa 10 pannelli forex 300x200".
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi add column if not exists descrizione_breve text default '';

-- Fine migrazione v72.
