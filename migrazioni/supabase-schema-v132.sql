-- =====================================================================
--  Migrazione v132 — Scotch a pezzi (quantità scelta sulla riga)
--  - imballo_input (jsonb) su righe preventivo/commessa: quantità manuali per
--    le voci imballo a input (es. n° pezzi di scotch per quella riga).
--  - aggiunge il modo "scotch" ai modi ammessi.
--  Additiva/correttiva, reversibile.
-- =====================================================================

alter table public.preventivi_righe add column if not exists imballo_input jsonb;
alter table public.commesse_righe  add column if not exists imballo_input jsonb;

alter table public.imballi_voci drop constraint if exists imballi_voci_modo_check;
alter table public.imballi_voci add constraint imballi_voci_modo_check
  check (modo in ('mq','mtl','perimetro','pellicola','scotch','scatola','mc','pz','ora','passaggio','battuta','fisso'));

-- Fine migrazione v132.
-- (Per annullare:
--   alter table public.preventivi_righe drop column imballo_input;
--   alter table public.commesse_righe  drop column imballo_input;)
