-- =====================================================================
--  MIGRAZIONE v69 - EMAIL DESTINATARIO sul PREVENTIVO
--
--  Sul preventivo si puo' indicare a quale persona/indirizzo e' rivolto,
--  senza dover caricare in anagrafica tutte le email dell'azienda.
--  I campi compaiono nell'intestazione del PDF ("Alla c.a. ... - email").
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi add column if not exists referente_dest text default '';
alter table public.preventivi add column if not exists email_dest     text default '';

-- Fine migrazione v69.
