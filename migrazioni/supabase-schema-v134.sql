-- =====================================================================
--  Migrazione v134 — Tracciare CHI ha chiuso una lavorazione
--  Quando un operatore preme "Chiudi" su una fase in Postazione, salviamo
--  chi l'ha chiusa e quando. (Chi ha LAVORATO e per quanto è già tracciato
--  in segmenti_lavoro; il consuntivo per fase si ricava da lì.)
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse_fasi
  add column if not exists chiusa_da_id   text,
  add column if not exists chiusa_da_nome text,
  add column if not exists chiusa_il      timestamptz;

-- Fine migrazione v134.
-- (Per annullare:
--   alter table public.commesse_fasi
--     drop column chiusa_da_id, drop column chiusa_da_nome, drop column chiusa_il;)
