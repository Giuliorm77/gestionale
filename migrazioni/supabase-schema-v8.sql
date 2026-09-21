-- =====================================================================
--  MIGRAZIONE v8 - Catalogo: costo interno, scorta minima, flag vendibile
--  (principi del piano: costo != prezzo; scorta minima per sottoscorta;
--   flag "vendibile" per la futura Vetrina/e-commerce)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.articoli add column if not exists costo         numeric(12,2) default 0;   -- costo interno (riservato)
alter table public.articoli add column if not exists scorta_minima numeric(12,2) default 0;   -- soglia sottoscorta
alter table public.articoli add column if not exists vendibile     boolean not null default false; -- pubblicabile online

-- Fine migrazione v8.
