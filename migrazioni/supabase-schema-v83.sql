-- =====================================================================
--  MIGRAZIONE v83 - CRM: provvigione visibile all'agente nel proprio CRM
--
--  L'agente deve poter vedere la SUA percentuale di provvigione per
--  stimare i propri guadagni nel CRM, MA la tabella "agenti" resta
--  riservata (economici). Invece di aprire la RLS di "agenti", esponiamo
--  una funzione security-definer che ritorna SOLO la % dell'agente loggato.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create or replace function public.my_provvigione_pct() returns numeric
language sql stable security definer set search_path = public
as $$ select provvigione_pct from public.agenti where id = public.my_agente_id(); $$;

grant execute on function public.my_provvigione_pct() to authenticated;

-- Fine migrazione v83.
