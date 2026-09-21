-- =====================================================================
--  MIGRAZIONE v57 - AGENTE sulla COMMESSA (override) per le provvigioni
--
--  La commessa eredita l'agente dal cliente; questo campo permette di
--  forzarne uno diverso sulla singola commessa (NULL = eredita dal cliente).
--  Serve al report "Provvigioni maturande" (Stage B).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse add column if not exists agente_id uuid references public.agenti(id) on delete set null;

-- Fine migrazione v57.
