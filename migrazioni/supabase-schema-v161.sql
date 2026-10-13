-- =====================================================================
--  Migrazione v161 — Spunta "Applica provvigione" per riga di preventivo
--  Permette di scegliere, riga per riga, se la provvigione agente si applica.
--  Default logico in app: ON per prodotti/materiali, OFF per lavorazioni.
--  Caso "prezzo netto all'agente": si toglie la spunta sulle righe interessate
--  (il ricarico resta all'agente, nessuna provvigione da riconoscere).
--  NULL in DB = non impostata -> l'app applica il default dal tipo riga.
-- =====================================================================

alter table public.preventivi_righe
  add column if not exists applica_provvigione boolean;

-- Fine migrazione v161.
