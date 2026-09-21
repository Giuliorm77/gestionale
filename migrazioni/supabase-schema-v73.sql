-- =====================================================================
--  MIGRAZIONE v73 - AFFIDABILITA' (stelline) sul CLIENTE
--
--  Come per i fornitori, un voto 0..5 stelle sull'affidabilita' del cliente
--  (pagamenti, chiarezza ordini, comportamento). Solo indicativo interno.
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.clienti add column if not exists affidabilita int default 0;   -- 0..5 stelle

-- Fine migrazione v73.
