-- =====================================================================
--  Migrazione v160 — Base provvigione = SOLO prodotti (no lavorazioni)
--  La provvigione agente va calcolata sulla sola quota PRODOTTI/MATERIALI
--  del valore, escludendo le lavorazioni (manodopera/impianto) e gli extra
--  (imballo/trasporto).
--  Aggiunge commesse.valore_prodotti: quota dei soli prodotti, calcolata
--  dalle righe del preventivo al momento della creazione commessa.
--  NULL = commessa vecchia/senza dettaglio -> si usa il valore intero (retrocompat).
-- =====================================================================

alter table public.commesse
  add column if not exists valore_prodotti numeric;

-- Fine migrazione v160.
