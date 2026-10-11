-- =====================================================================
--  Migrazione v158 — Nominativo libero sulle attività CRM
--  Permette di registrare un'attività (chiamata, ecc.) per un contatto che
--  NON è ancora un cliente in anagrafica: campo testo libero "contatto".
-- =====================================================================

alter table public.crm_attivita
  add column if not exists contatto text default '';

-- Fine migrazione v158.
