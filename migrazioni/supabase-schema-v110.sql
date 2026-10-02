-- =====================================================================
--  Migrazione v110 — Fasi di lavorazione AGGIUNTE dopo la creazione commessa
--  Una lavorazione aggiunta a commessa gia' creata = lavoro FUORI preventivo:
--  va segnalata (aggiornare il preventivo o aggiungerla in fattura).
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse_fasi
  add column if not exists aggiunta boolean not null default false;

-- Anche i MATERIALI (righe) aggiunti a commessa gia' creata = fuori preventivo.
alter table public.commesse_righe
  add column if not exists aggiunta boolean not null default false;

-- Fine migrazione v110.
-- (Per annullare:
--    alter table public.commesse_fasi  drop column aggiunta;
--    alter table public.commesse_righe drop column aggiunta;)
