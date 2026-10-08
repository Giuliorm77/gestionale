-- =====================================================================
--  Migrazione v121 — Rilascio in produzione esplicito della commessa
--  Finché il back office non preme "Manda in produzione" la commessa è
--  "in preparazione" e NON compare nella Postazione operatori.
--  Le commesse GIA' esistenti vengono rilasciate (per non bloccarle).
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse
  add column if not exists rilasciata_produzione boolean not null default false,
  add column if not exists rilasciata_il          timestamptz;

-- Backfill: tutte le commesse già create risultano rilasciate (erano già operative).
update public.commesse
   set rilasciata_produzione = true,
       rilasciata_il = coalesce(rilasciata_il, creato_il, now())
 where rilasciata_produzione = false;

-- Fine migrazione v121.
-- (Per annullare:
--   alter table public.commesse drop column rilasciata_produzione, drop column rilasciata_il;)
