-- =====================================================================
--  MIGRAZIONE v22 - Righe preventivo riapribili
--  Salva la configurazione (prodotto, variante, misure, quantità, opzioni,
--  imballo) dietro la riga, per poterla riaprire e modificare.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi_righe add column if not exists config jsonb;

-- Fine migrazione v22.
