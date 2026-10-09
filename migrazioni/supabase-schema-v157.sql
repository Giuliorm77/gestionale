-- =====================================================================
--  Migrazione v157 — Spese generali (gestione) nel consuntivo
--  Aggiunge la voce spese generali allo snapshot del consuntivo.
--  La % usata è quella di Impostazioni (impostazioni.spese_generali_pct),
--  applicata ai costi diretti (materiali + manodopera), come nel preventivo.
-- =====================================================================

alter table public.commesse_consuntivi
  add column if not exists costo_spese_generali numeric(12,2) default 0;

-- Fine migrazione v157.
