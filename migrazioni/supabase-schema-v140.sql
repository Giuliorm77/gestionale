-- =====================================================================
--  Migrazione v140 — Preventivo multi-prodotto: raggruppa i componenti per prodotto
--  Ogni riga (componente/lavorazione) appartiene a un PRODOTTO (gruppo), così nel
--  preventivo i componenti sono raccolti per prodotto e il PDF cliente mostra una
--  riga per prodotto (es. Espositore, Totem).
--  Additiva e reversibile.
-- =====================================================================

alter table public.preventivi_righe add column if not exists gruppo text;
alter table public.commesse_righe  add column if not exists gruppo text;

-- Fine migrazione v140.
-- (Per annullare:
--   alter table public.preventivi_righe drop column gruppo;
--   alter table public.commesse_righe  drop column gruppo;)
