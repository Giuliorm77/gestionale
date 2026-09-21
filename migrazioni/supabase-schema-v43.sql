-- =====================================================================
--  MIGRAZIONE v43 - Costi di struttura (per calcolare le Spese Generali %)
--
--  Elenco dei costi indiretti/di struttura (affitto, personale indiretto,
--  amministrazione, software...) con importo annuo. Con i costi diretti
--  annui stimati, l'app propone la % di spese generali da usare.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists costi_struttura     jsonb default '[]'::jsonb;  -- [{categoria, descrizione, importo}]
alter table public.impostazioni add column if not exists costi_diretti_annui  numeric default 0;          -- base per la %
alter table public.impostazioni add column if not exists fatturato_annuo      numeric default 0;          -- informativo

-- Fine migrazione v43.
