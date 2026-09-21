-- =====================================================================
--  MIGRAZIONE v94 - Abbondanza per lato (cm) sui materiali a mq/ml
--
--  Sostituisce la % di abbondanza (v92) con un modello dimensionale corretto:
--  si aggiunge N cm PER LATO alla misura netta -> area/lunghezza maggiorata su
--  cui si calcola il consumo/costo del materiale. Le misure nette (mostrate al
--  cliente) NON cambiano. Default globale 3 cm, override per riga; in futuro
--  un default per materiale/categoria (fallback al globale).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists abbondanza_cm numeric default 3;
update public.impostazioni set abbondanza_cm = 3 where abbondanza_cm is null;

-- (predisposizione futura) default per articolo/categoria; fallback al globale se null
alter table public.articoli add column if not exists abbondanza_cm numeric;

-- Fine migrazione v94.
