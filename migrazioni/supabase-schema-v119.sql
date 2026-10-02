-- =====================================================================
--  Migrazione v119 — Quantità DA FARE sulle lavorazioni (fasi)
--  Es. "500 battute": compare sulla scheda di lavorazione per la produzione.
--  (La quantità GIA' lavorata resta in quantita_lavorata; l'unità in unita_lavorata.)
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse_fasi
  add column if not exists quantita_prevista numeric;

-- Fine migrazione v119.
-- (Per annullare: alter table public.commesse_fasi drop column quantita_prevista;)
