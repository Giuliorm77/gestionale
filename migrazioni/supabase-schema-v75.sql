-- =====================================================================
--  MIGRAZIONE v75 - PIU' IMBALLI PER RIGA (selezione multipla)
--
--  Su una riga di prodotto ora si possono scegliere PIU' imballi insieme
--  (es. pluriball + scotch + angolari + parabordi). Prima era uno solo.
--  Si aggiunge una lista "imballo_ids" (array di id ricetta imballo).
--  Il pluriball resta separato in "imballo_pluriball" (v74), perche' e'
--  a calcolo automatico e collegato al magazzino.
--
--  Migra il vecchio "imballo_id" singolo dentro la nuova lista.
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi_righe add column if not exists imballo_ids jsonb not null default '[]'::jsonb;
alter table public.commesse_righe   add column if not exists imballo_ids jsonb not null default '[]'::jsonb;

-- Porta il vecchio imballo_id singolo nella nuova lista (una tantum)
update public.preventivi_righe
   set imballo_ids = jsonb_build_array(imballo_id::text)
 where imballo_id is not null
   and (imballo_ids is null or imballo_ids = '[]'::jsonb);

update public.commesse_righe
   set imballo_ids = jsonb_build_array(imballo_id::text)
 where imballo_id is not null
   and (imballo_ids is null or imballo_ids = '[]'::jsonb);

-- Fine migrazione v75.
