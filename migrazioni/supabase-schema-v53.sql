-- =====================================================================
--  MIGRAZIONE v53 - LAVORAZIONI ESTERNE (conto terzi) sulle fasi commessa
--
--  Una fase della commessa puo' essere "esterna": invece di operatori/ore
--  interni ha un TERZISTA (fornitore) + costo + date di invio/rientro + stato.
--  Il costo reale entra nel consuntivo; la data di rientro nella tempistica.
--
--  Stati fase esterna (nel campo `stato`): 'da_inviare' | 'inviata' | 'rientrata'.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_fasi add column if not exists esterna               boolean default false;
alter table public.commesse_fasi add column if not exists fornitore_id           uuid;
alter table public.commesse_fasi add column if not exists fornitore_nome         text default '';
alter table public.commesse_fasi add column if not exists costo_previsto         numeric default 0;
alter table public.commesse_fasi add column if not exists costo_reale            numeric default 0;
alter table public.commesse_fasi add column if not exists data_invio             date;
alter table public.commesse_fasi add column if not exists data_rientro_prevista  date;
alter table public.commesse_fasi add column if not exists data_rientro           date;

-- Fine migrazione v53.
