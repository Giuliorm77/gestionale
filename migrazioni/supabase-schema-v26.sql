-- =====================================================================
--  MIGRAZIONE v26 - Area utile della carta intestata (margini PDF)
--  Il contenuto del preventivo resta dentro quest'area su OGNI pagina,
--  andando a capo da solo quando le righe sono tante.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- carta_margine_top esiste gia' (v24) = margine superiore (mm)
alter table public.impostazioni add column if not exists carta_margine_bottom int default 25;  -- margine inferiore (mm)
alter table public.impostazioni add column if not exists carta_margine_lati   int default 15;  -- margini laterali (mm)

-- Fine migrazione v26.
