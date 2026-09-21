-- =====================================================================
--  MIGRAZIONE v36 - Costo trasporto sulla commessa
--  In commessa si calcola il trasporto reale (peso/colli effettivi) con lo
--  stesso calcolatore del preventivo, salvando il costo.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse add column if not exists trasporto numeric(12,2) default 0;

-- Fine migrazione v36.
