-- =====================================================================
--  Migrazione v154 — Provvigione agente come costo nel consuntivo
--  Aggiunge la voce provvigione allo snapshot del consuntivo.
-- =====================================================================

alter table public.commesse_consuntivi
  add column if not exists costo_provvigione numeric(12,2) default 0;

-- Fine migrazione v154.
