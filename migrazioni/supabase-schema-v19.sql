-- =====================================================================
--  MIGRAZIONE v19 - Nuovo modo di calcolo: "a passaggio foglio" (€/passaggio)
--  Per la stampa digitale piccolo formato conteggiata a passaggio.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.prodotti_config_voci drop constraint if exists prodotti_config_voci_modo_check;
alter table public.prodotti_config_voci add  constraint prodotti_config_voci_modo_check
  check (modo in ('mq','mtl','ml','mc','pz','fisso','ora','passaggio'));

-- Fine migrazione v19.
