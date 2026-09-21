-- =====================================================================
--  MIGRAZIONE v23 - Dati azienda per i documenti (PDF preventivo)
--  Aggiunge alla riga Impostazioni i dati dell'azienda (carta intestata)
--  e le condizioni di vendita predefinite.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists azienda_nome       text default '';
alter table public.impostazioni add column if not exists azienda_indirizzo  text default '';
alter table public.impostazioni add column if not exists azienda_citta      text default '';
alter table public.impostazioni add column if not exists azienda_piva       text default '';
alter table public.impostazioni add column if not exists azienda_email      text default '';
alter table public.impostazioni add column if not exists azienda_tel        text default '';
alter table public.impostazioni add column if not exists azienda_iban       text default '';
alter table public.impostazioni add column if not exists condizioni_default text default '';

-- Fine migrazione v23.
