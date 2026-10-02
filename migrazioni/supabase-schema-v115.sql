-- =====================================================================
--  Migrazione v115 — Numero preventivo di origine sulla commessa
--  La commessa ha gia' preventivo_id (link); aggiungiamo il NUMERO leggibile
--  come snapshot, per mostrarlo nella commessa e nell'elenco.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse
  add column if not exists preventivo_numero text;

-- Riempimento per le commesse gia' esistenti (dove il preventivo esiste ancora).
update public.commesse c
   set preventivo_numero = p.numero
  from public.preventivi p
 where c.preventivo_id = p.id
   and (c.preventivo_numero is null or c.preventivo_numero = '');

-- Fine migrazione v115.
-- (Per annullare: alter table public.commesse drop column preventivo_numero;)
