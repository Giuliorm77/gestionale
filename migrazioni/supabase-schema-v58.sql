-- =====================================================================
--  MIGRAZIONE v58 - Flag fiscali sul cliente
--
--  Per le varie casistiche di fatturazione:
--   - fattura_elettronica: il cliente riceve fattura elettronica (SDI) oppure no
--     (es. privati/esteri). Default true (caso piu' comune in Italia).
--   - split_payment: scissione dei pagamenti (art. 17-ter, tipicamente PA/enti).
--     Default false.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.clienti add column if not exists fattura_elettronica boolean default true;
alter table public.clienti add column if not exists split_payment boolean default false;

-- Fine migrazione v58.
