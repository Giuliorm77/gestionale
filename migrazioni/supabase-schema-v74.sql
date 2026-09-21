-- =====================================================================
--  MIGRAZIONE v74 - PLURIBALL come imballo PER RIGA (non piu' nel configuratore)
--
--  Il pluriball non e' piu' incluso nel prodotto configurato: si sceglie sulla
--  singola riga del preventivo/commessa (stesso menu' dell'imballo, voce
--  "Pluriball automatico"). Serve un campo per memorizzare la bobina e i metri
--  scelti su quella riga (per lo scarico magazzino e la scheda di produzione).
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi_righe add column if not exists imballo_pluriball jsonb;   -- {articolo_id, nome, mtl, mtl_tot, prezzo_unit}
alter table public.commesse_righe   add column if not exists imballo_pluriball jsonb;

-- Fine migrazione v74.
