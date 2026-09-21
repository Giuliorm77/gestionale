-- =====================================================================
--  MIGRAZIONE v20 - Nuovo modo di calcolo: "a battuta" (€/battuta)
--  Per la serigrafia conteggiata a battuta.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.prodotti_config_voci drop constraint if exists prodotti_config_voci_modo_check;
alter table public.prodotti_config_voci add  constraint prodotti_config_voci_modo_check
  check (modo in ('mq','mtl','ml','mc','pz','fisso','ora','passaggio','battuta'));

-- Fine migrazione v20.
