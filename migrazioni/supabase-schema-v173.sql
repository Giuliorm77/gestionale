-- =====================================================================
--  Migrazione v173 — Leva commerciale: sconto da applicare in fattura
--  Dal consuntivo reale, se il lavoro è costato meno del previsto, si può
--  concedere al cliente uno sconto (al massimo il margine extra rispetto al
--  preventivo). Lo sconto resta sulla commessa: il margine reale lo sottrae
--  e il Back office lo applica quando fattura in Fatture in Cloud.
-- =====================================================================

alter table public.commesse add column if not exists sconto_fattura numeric(12,2) not null default 0;
alter table public.commesse add column if not exists sconto_nota    text default '';

-- Fine migrazione v173.
