-- =====================================================================
--  Migrazione v135 — Distinta consumi per lavorazione (costo reale)
--  Ogni tariffa lavorazione può avere una distinta dei consumi (inchiostro,
--  gelatina, corrente, ammortamento…) da cui si calcola il COSTO reale per
--  unità. Modello "misto": voci forfait (€/unità), voci a €/mq (× superficie
--  media), voci a % del prezzo.
--  - consumi: jsonb [{descrizione, modo:'cad'|'mq'|'pct', valore}]
--  - sup_media_mq: superficie media per unità, per le voci a €/mq (es. inchiostro)
--  Additiva e reversibile.
-- =====================================================================

alter table public.impostazioni_lavorazioni
  add column if not exists consumi      jsonb,
  add column if not exists sup_media_mq numeric not null default 0;

-- Fine migrazione v135.
-- (Per annullare:
--   alter table public.impostazioni_lavorazioni
--     drop column consumi, drop column sup_media_mq;)
