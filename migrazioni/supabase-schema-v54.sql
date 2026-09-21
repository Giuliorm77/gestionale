-- =====================================================================
--  MIGRAZIONE v54 - ORE DI STRAORDINARIO sulle fasi commessa
--
--  Ore di straordinario per fase, costate a una tariffa FISSA (valore di
--  test: 10 €/h, costante COSTO_STRAORDINARIO nel codice). Entrano nel
--  consuntivo della commessa come costo aggiuntivo.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_fasi add column if not exists ore_straordinario numeric default 0;

-- Fine migrazione v54.
