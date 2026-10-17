-- =====================================================================
--  Migrazione v175 — Trasporto calcolato in automatico nel preventivo
--  Non tutti i corrieri accettano i pacchi voluminosi: su ogni listino
--  si indicano i LIMITI (lato massimo, peso massimo per collo).
--  Il preventivo, per le righe con consegna "Corriere", sceglie il listino
--  PIU' ECONOMICO tra quelli che accettano il pacco (modificabile a mano).
-- =====================================================================

alter table public.corrieri   add column if not exists max_lato_cm        numeric;   -- null = nessun limite
alter table public.corrieri   add column if not exists max_peso_collo_kg  numeric;   -- null = nessun limite

alter table public.preventivi add column if not exists trasporto_auto        boolean default false;
alter table public.preventivi add column if not exists trasporto_corriere_id uuid;   -- listino scelto a mano (null = il più economico)

-- Fine migrazione v175.
