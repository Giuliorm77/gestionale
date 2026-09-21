-- =====================================================================
--  v98 - Helper per il BACKUP: elenco automatico delle tabelle
--
--  PERCHE': lo script di backup scopriva le tabelle leggendo la specifica
--  OpenAPI su GET /rest/v1/ . Con le NUOVE chiavi API di Supabase
--  (sb_publishable_ / sb_secret_) quell'endpoint risponde 401, quindi la
--  scoperta falliva e il backup ripiegava su una lista di riserva parziale.
--
--  SOLUZIONE: una funzione che restituisce l'elenco delle tabelle "base"
--  dello schema public. Si chiama come una normale query (rpc), quindi
--  funziona con la service_role e cattura anche le tabelle FUTURE.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create or replace function public.backup_lista_tabelle()
returns text[]
language sql
security definer
set search_path = public
as $$
  select coalesce(array_agg(table_name order by table_name), '{}')
  from information_schema.tables
  where table_schema = 'public'
    and table_type   = 'BASE TABLE';
$$;

comment on function public.backup_lista_tabelle() is
  'Elenco delle tabelle base di public: usato dallo script di backup per scoprire cosa salvare.';

-- Eseguibile SOLO dal server (service_role). Non serve ad anon/authenticated.
-- NB: Supabase concede l'EXECUTE sulle nuove funzioni public anche ad
-- anon/authenticated (default privileges), quindi vanno revocati esplicitamente.
revoke all on function public.backup_lista_tabelle() from public, anon, authenticated;
grant execute on function public.backup_lista_tabelle() to service_role;

-- Fine v98.
