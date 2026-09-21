-- =====================================================================
--  MIGRAZIONE v68 - CAPIENZA sulle ricette imballo (scatole)
--
--  Per contare le SCATOLE serve sapere quanti pezzi entrano in una scatola.
--  n. scatole = ceil(quantita / capienza). Le voci con modo "a scatola"
--  (scatola stessa, scotch di chiusura, ecc.) si moltiplicano per il n. scatole.
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.imballi add column if not exists capienza numeric default 0;

-- Fine migrazione v68.
