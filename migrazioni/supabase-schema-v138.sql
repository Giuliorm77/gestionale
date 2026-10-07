-- =====================================================================
--  Migrazione v138 — Struttura automatica per larghezza (prodotti compositi)
--  - articoli.larghezza_cm: larghezza (cm) di una struttura, per far scegliere
--    automaticamente la struttura giusta nel composito (es. Struttura rollup 85).
--  - prodotti_compositi.altezza_default: altezza predefinita (cm) proposta in
--    preventivo per i compositi a misura libera (es. rollup altezza 200).
--  Additiva e reversibile.
-- =====================================================================

alter table public.articoli
  add column if not exists larghezza_cm numeric;

alter table public.prodotti_compositi
  add column if not exists altezza_default numeric;

-- Fine migrazione v138.
-- (Per annullare:
--   alter table public.articoli drop column larghezza_cm;
--   alter table public.prodotti_compositi drop column altezza_default;)
