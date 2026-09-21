-- =====================================================================
--  MIGRAZIONE v16 - Prodotti configurabili: modo di calcolo "a tempo" (€/ora)
--  Per lavorazioni/macchine che si conteggiano a ora.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.prodotti_config_voci drop constraint if exists prodotti_config_voci_modo_check;
alter table public.prodotti_config_voci add  constraint prodotti_config_voci_modo_check
  check (modo in ('mq','mtl','ml','mc','pz','fisso','ora'));

-- Fine migrazione v16.
