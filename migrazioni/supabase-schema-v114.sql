-- =====================================================================
--  Migrazione v114 — Totale manuale per la versione cliente del preventivo
--  Se valorizzato, il PDF cliente mostra le voci spuntate (senza prezzi riga)
--  e stampa questo totale deciso a mano. Solo per la stampa.
--  Additiva e reversibile.
-- =====================================================================

alter table public.preventivi
  add column if not exists cliente_totale numeric;

-- Fine migrazione v114.
-- (Per annullare: alter table public.preventivi drop column cliente_totale;)
