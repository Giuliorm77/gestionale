-- =====================================================================
--  MIGRAZIONE v82 - FIX vincolo ruoli su profiles (aggiunge 'agente' e 'magazzino')
--
--  Il CHECK originale su profiles.ruolo ammetteva solo:
--    amministratore | commerciale | produzione | reception
--  Mancavano 'magazzino' (ruolo gia' usato dall'app) e 'agente' (nuovo CRM):
--  assegnarli dava "profiles_ruolo_check violation".
--
--  Qui allarghiamo il vincolo a TUTTI i ruoli validi.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.profiles drop constraint if exists profiles_ruolo_check;

alter table public.profiles
  add constraint profiles_ruolo_check
  check (ruolo in ('amministratore','commerciale','agente','produzione','magazzino','reception'));

-- Fine migrazione v82.
