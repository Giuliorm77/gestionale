-- =====================================================================
--  Migrazione v155 — % provvigione sulla commessa (ereditata dal preventivo)
--  Permette alla commessa di portarsi dietro la % di provvigione decisa nel
--  preventivo (override), così il calcolo provvigioni in commessa/report
--  coincide con quello del preventivo anche quando il cliente non ha un agente
--  di default. Se null → si usa la % del cliente/agente come prima.
-- =====================================================================

alter table public.commesse
  add column if not exists provvigione_pct numeric;

-- Fine migrazione v155.
