-- =====================================================================
--  MIGRAZIONE v18 - Tariffe per lavorazione: MODO DI CALCOLO
--  Ogni lavorazione puo' essere conteggiata a ora / mq / mtl / mc / pz / fisso.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni_lavorazioni add column if not exists modo text default 'ora';

-- Fine migrazione v18.  (il valore in "tariffa_oraria" ora rappresenta la tariffa
--  per l'unita scelta nel campo "modo": €/ora, €/mq, €/mc, ...)
