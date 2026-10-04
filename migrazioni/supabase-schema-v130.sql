-- =====================================================================
--  Migrazione v130 — Imballo pannelli: abbondanza + pezzi-per-pezzo sulle voci
--  - abbondanza_cm: cm aggiunti PER LATO alla misura (pellicola/pluriball che avvolge)
--    applicata alle voci a mq/mtl/mc/perimetro.
--  - qta_pezzo: n° pezzi del componente per ogni pezzo lavorato (es. 4 angolari/pannello)
--    per le voci "a pezzo".
--  Additiva e reversibile.
-- =====================================================================

alter table public.imballi_voci
  add column if not exists abbondanza_cm numeric not null default 0,
  add column if not exists qta_pezzo     numeric not null default 0;

-- Fine migrazione v130.
-- (Per annullare:
--   alter table public.imballi_voci drop column abbondanza_cm, drop column qta_pezzo;)
