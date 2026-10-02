-- =====================================================================
--  Migrazione v116 — Costo unitario STIMATO sulle righe di commessa
--  Serve come riferimento "preventivato" per la spia di confronto col costo
--  reale pagato (dagli ordini fornitore collegati). Non cambia il margine.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse_righe
  add column if not exists costo_unitario numeric;

-- Fine migrazione v116.
-- (Per annullare: alter table public.commesse_righe drop column costo_unitario;)
