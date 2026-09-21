-- =====================================================================
--  MIGRAZIONE v81 - CRM rete agenti (FASE 4: isolamento RLS per agente)
--
--  Regola: un AGENTE vede/gestisce SOLO i clienti, le trattative e le
--  attivita' a lui assegnati (agente_id = il suo). Tutti gli altri ruoli
--  (amministratore, commerciale, produzione, magazzino, reception) vedono
--  i clienti come prima (nessuna regressione).
--
--  NB: la RLS su "clienti" era GIA' attiva con lettura aperta a tutti gli
--  approvati; qui la SOSTITUIAMO per isolare l'agente senza togliere
--  accesso agli altri ruoli.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
--  ⚠️ Dopo l'esecuzione: TESTARE ruolo per ruolo prima di costruire la UI.
-- =====================================================================

-- Helper: id agente collegato all'utente loggato (null se non e' un agente)
create or replace function public.my_agente_id() returns uuid
language sql stable security definer set search_path = public
as $$ select agente_id from public.profiles where id = auth.uid(); $$;
grant execute on function public.my_agente_id() to authenticated;

-- ---------------------------------------------------------------------
-- CLIENTI: sostituisco le policy per isolare SOLO l'agente
-- ---------------------------------------------------------------------
drop policy if exists clienti_select on public.clienti;
create policy clienti_select on public.clienti for select to authenticated
  using (
    public.ruolo_utente() is not null
    and ( public.ruolo_utente() <> 'agente' or agente_id = public.my_agente_id() )
  );

drop policy if exists clienti_insert on public.clienti;
create policy clienti_insert on public.clienti for insert to authenticated
  with check (
    public.ruolo_utente() in ('amministratore','commerciale','reception')
    or ( public.ruolo_utente() = 'agente' and agente_id = public.my_agente_id() )
  );

drop policy if exists clienti_update on public.clienti;
create policy clienti_update on public.clienti for update to authenticated
  using (
    public.ruolo_utente() in ('amministratore','commerciale')
    or ( public.ruolo_utente() = 'agente' and agente_id = public.my_agente_id() )
  )
  with check (
    public.ruolo_utente() in ('amministratore','commerciale')
    or ( public.ruolo_utente() = 'agente' and agente_id = public.my_agente_id() )
  );

-- clienti_delete resta invariata (solo amministratore).

-- ---------------------------------------------------------------------
-- CRM_TRATTATIVE: admin/commerciale tutto; agente solo i propri
-- ---------------------------------------------------------------------
alter table public.crm_trattative enable row level security;
drop policy if exists tratt_all on public.crm_trattative;
create policy tratt_all on public.crm_trattative for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') or agente_id = public.my_agente_id() )
  with check ( public.ruolo_utente() in ('amministratore','commerciale') or agente_id = public.my_agente_id() );

-- ---------------------------------------------------------------------
-- CRM_ATTIVITA: stesse regole
-- ---------------------------------------------------------------------
alter table public.crm_attivita enable row level security;
drop policy if exists att_all on public.crm_attivita;
create policy att_all on public.crm_attivita for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') or agente_id = public.my_agente_id() )
  with check ( public.ruolo_utente() in ('amministratore','commerciale') or agente_id = public.my_agente_id() );

-- Fine migrazione v81.
