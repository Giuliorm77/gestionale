-- =====================================================================
--  Migrazione v136 — Obiettivo di margine per categoria
--  Margine lordo minimo desiderato per categoria (famiglia merceologica
--  articoli, o nome lavorazione). Nel preventivo le righe sotto l'obiettivo
--  vengono segnalate; le categorie non elencate usano il margine minimo
--  generale già esistente.
--  margini_categoria: jsonb [{categoria, obiettivo}]
--  Additiva e reversibile.
-- =====================================================================

alter table public.impostazioni
  add column if not exists margini_categoria jsonb;

-- Fine migrazione v136.
-- (Per annullare: alter table public.impostazioni drop column margini_categoria;)
