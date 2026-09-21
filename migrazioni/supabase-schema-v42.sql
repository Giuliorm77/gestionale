-- =====================================================================
--  MIGRAZIONE v42 - Quantità lavorata sulla fase (per la produttività reale)
--
--  Su ogni fase della commessa la produzione può indicare QUANTO ha
--  lavorato quel reparto (es. 350 mq, 1200 battute). Con le ore reali, il
--  Report ricava la PRODUTTIVITÀ (mq/ora) per ritarare le tariffe.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_fasi add column if not exists quantita_lavorata numeric(12,2) default 0;
alter table public.commesse_fasi add column if not exists unita_lavorata    text default '';

-- Fine migrazione v42.
