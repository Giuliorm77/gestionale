-- =====================================================================
--  Migrazione v144 — Preventivo a SCAGLIONI di quantità
--  Un preventivo può avere più prodotti che:
--   - si SOMMANO (prodotti diversi: Espositore + Totem) → comportamento normale
--   - sono ALTERNATIVE di quantità (stesso prodotto a 100 / 250 / 500 pz):
--     non si sommano, il cliente ne sceglie una (tabella quantità → prezzo).
--  - scaglioni:     boolean  (true = modalità scaglioni/alternative)
--  - scaglioni_qta: jsonb    (mappa gruppo→quantità, es. {"Adesivo 100":100,"Adesivo 250":250})
--  Additiva e reversibile.
-- =====================================================================

alter table public.preventivi
  add column if not exists scaglioni     boolean not null default false,
  add column if not exists scaglioni_qta jsonb;

-- Fine migrazione v144.
-- (Per annullare:
--   alter table public.preventivi drop column scaglioni, drop column scaglioni_qta;)
