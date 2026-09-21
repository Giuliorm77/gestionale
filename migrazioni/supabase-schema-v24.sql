-- =====================================================================
--  MIGRAZIONE v24 - Carta intestata (sfondo) per il PDF preventivo
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists carta_intestata   text default '';   -- immagine A4 (data URL) o URL
alter table public.impostazioni add column if not exists carta_margine_top  int  default 40;  -- mm: spazio in alto per non coprire l'intestazione

-- Fine migrazione v24.
