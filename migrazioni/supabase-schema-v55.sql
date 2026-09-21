-- =====================================================================
--  MIGRAZIONE v55 - STRAORDINARI per operatore (con data) sulla commessa
--
--  Ogni voce: { operatore_id, nome, ore, data }. Costati a tariffa FISSA
--  (COSTO_STRAORDINARIO nel codice, oggi 10 €/h). Servono al consuntivo
--  della commessa E al report mensile per operatore (busta paga).
--
--  NB: la v54 (commesse_fasi.ore_straordinario) e' stata SUPERATA da questa
--  versione per-operatore: quella colonna resta ma non e' piu' usata.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse add column if not exists straordinari jsonb default '[]'::jsonb;

-- Fine migrazione v55.
