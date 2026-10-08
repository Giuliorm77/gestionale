-- =====================================================================
--  Migrazione v143 — Extra costi / spese impreviste sulla commessa
--  Spese impreviste emerse durante la lavorazione, caricate sulla commessa
--  (riga libera: descrizione + costo + data + chi + flag riaddebito cliente).
--  Entrano nel consuntivo reale e avvisano alla chiusura.
--  Stesso schema jsonb di consumi/aiuti/straordinari.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse
  add column if not exists extra_costi jsonb;

-- Fine migrazione v143.
-- (Per annullare: alter table public.commesse drop column extra_costi;)
