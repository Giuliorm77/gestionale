-- =====================================================================
--  MIGRAZIONE v41 - Sedi ed email multiple per i Dati azienda (Impostazioni)
--
--  Sull'unica riga impostazioni salviamo due elenchi JSON:
--    azienda_sedi   = [{tipo, indirizzo, cap, citta, provincia}]
--    azienda_emails = [{categoria, indirizzo}]
--  I campi singoli azienda_indirizzo/azienda_citta/azienda_email restano e
--  vengono allineati dall'app (sede legale + prima email) per il PDF.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists azienda_sedi   jsonb default '[]'::jsonb;
alter table public.impostazioni add column if not exists azienda_emails jsonb default '[]'::jsonb;

-- Fine migrazione v41.
