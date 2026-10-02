-- =====================================================================
--  Migrazione v118 — Prezzo di vendita sulle righe di commessa
--  Serve per gli articoli AGGIUNTI dopo il preventivo (fuori preventivo):
--  il loro prezzo diventa un "extra da fatturare" e entra in ricavi/margine.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse_righe
  add column if not exists prezzo_unitario numeric;

-- Fine migrazione v118.
-- (Per annullare: alter table public.commesse_righe drop column prezzo_unitario;)
