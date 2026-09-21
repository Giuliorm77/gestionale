-- =====================================================================
--  MIGRAZIONE v3 - Regione + Orari/Giorni di apertura per SEDE
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> New query -> Run.
--  Sicura da ri-eseguire: usa "if not exists".
-- =====================================================================

alter table public.clienti_sedi add column if not exists regione           text default '';
alter table public.clienti_sedi add column if not exists giorni_apertura   text[] not null default '{}';
alter table public.clienti_sedi add column if not exists orario_mattino    text default '';
alter table public.clienti_sedi add column if not exists orario_pomeriggio text default '';

-- Fine migrazione v3.
