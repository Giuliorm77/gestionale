-- =====================================================================
--  Migrazione v117 — "Prodotto" (cosa si produce) sulla commessa
--  Compare in cima alla scheda di lavorazione, sopra componenti e lavorazioni.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse
  add column if not exists prodotto text;

-- Backfill: per le commesse già create, usa la descrizione breve del preventivo.
update public.commesse c
   set prodotto = p.descrizione_breve
  from public.preventivi p
 where c.preventivo_id = p.id
   and (c.prodotto is null or c.prodotto = '')
   and coalesce(p.descrizione_breve,'') <> '';

-- Fine migrazione v117.
-- (Per annullare: alter table public.commesse drop column prodotto;)
