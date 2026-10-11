-- =====================================================================
--  Migrazione v159 — Referente (persona) sulle attività CRM
--  Un'azienda ha più persone: su ogni interazione si registra CON CHI si è
--  parlato. Lo storico del cliente si può così filtrare per persona.
-- =====================================================================

alter table public.crm_attivita
  add column if not exists referente text default '';

-- Fine migrazione v159.
