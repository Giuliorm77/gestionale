-- =====================================================================
--  Migrazione v113 — Versione sintetica per il cliente (righe personalizzate)
--  Righe scritte a mano (descrizione+prezzo) mostrate sul PDF cliente al posto
--  del dettaglio. Solo per la stampa: non cambia righe/commessa.
--  Additiva e reversibile.
-- =====================================================================

alter table public.preventivi
  add column if not exists righe_cliente jsonb;

-- Fine migrazione v113.
-- (Per annullare: alter table public.preventivi drop column righe_cliente;)
