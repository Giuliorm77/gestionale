-- =====================================================================
--  Migrazione v124 — Prezzo d'acquisto "controllato" sulle righe ordine fornitore
--  Il prezzo è precompilato dal listino (in rosso) e l'operatore deve spuntare
--  "controllato" prima di ricevere la merce (verifica che il prezzo del fornitore
--  coincida con quello in gestionale). Additiva e reversibile.
-- =====================================================================

alter table public.ordini_fornitore_righe
  add column if not exists prezzo_verificato boolean not null default false;

-- Fine migrazione v124.
-- (Per annullare: alter table public.ordini_fornitore_righe drop column prezzo_verificato;)
