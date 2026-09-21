-- =====================================================================
--  MIGRAZIONE v25 - Margine superiore della pagina condizioni (PDF)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists carta_margine_top_cond int default 45;  -- mm: da dove parte il testo delle condizioni

-- Fine migrazione v25.
