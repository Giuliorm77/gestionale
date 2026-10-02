-- =====================================================================
--  Migrazione v120 — Avviso di VARIAZIONE/DISDETTA per la produzione
--  Chi riceve la modifica/disdetta del cliente (anche la sera, da telefono)
--  scrive un avviso sulla commessa: la produzione lo vede in cima al cruscotto
--  e sulla scheda, prima di iniziare. Lo imposta solo amm/back office.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse
  add column if not exists avviso_produzione text,
  add column if not exists avviso_il         timestamptz;

-- Fine migrazione v120.
-- (Per annullare:
--   alter table public.commesse drop column avviso_produzione, drop column avviso_il;)
