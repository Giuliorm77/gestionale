-- =====================================================================
--  MIGRAZIONE v44 - Tipo operatore (produzione / misto / struttura)
--
--  Ogni operatore ha un tipo:
--    'produzione' -> solo manodopera diretta (ore sulle commesse)
--    'misto'      -> anche produzione: costo_annuo + ore_produzione/anno;
--                    la quota ufficio (annuo − ore×costo_orario) va da sola
--                    nelle Spese Generali
--    'struttura'  -> solo indiretto: tutto il costo_annuo va in struttura
--  Così la persona si definisce UNA volta sola (in Operatori) e il sistema
--  capisce come ripartire il costo.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.operatori add column if not exists tipo           text default 'produzione';
alter table public.operatori add column if not exists costo_annuo     numeric default 0;
alter table public.operatori add column if not exists ore_produzione  numeric default 0;

-- Fine migrazione v44.
