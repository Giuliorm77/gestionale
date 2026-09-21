-- =====================================================================
--  MIGRAZIONE v88 - Registro feedback clienti (ISO REG QA-9.1.2)
--
--  Registra il feedback/soddisfazione del cliente per anno. Da qui il
--  gestionale genera in automatico l'Excel del registro ISO (righe +
--  calcoli per anno).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.clienti_feedback (
  id           uuid primary key default gen_random_uuid(),
  cliente_id   uuid references public.clienti(id) on delete cascade,
  cliente_nome text default '',                     -- snapshot ragione sociale
  anno         int  not null,
  feedback     text not null                        -- Positivo | Parzialmente positivo | Negativo
               check (feedback in ('Positivo','Parzialmente positivo','Negativo')),
  note         text default '',
  creato_da    uuid references public.profiles(id),
  creato_il    timestamptz not null default now()
);
create index if not exists idx_cli_feedback_cli  on public.clienti_feedback(cliente_id);
create index if not exists idx_cli_feedback_anno on public.clienti_feedback(anno);

alter table public.clienti_feedback enable row level security;

-- Lettura: tutti gli utenti approvati. Scrittura: ruoli che gestiscono l'anagrafica/qualità.
drop policy if exists cli_feedback_select on public.clienti_feedback;
create policy cli_feedback_select on public.clienti_feedback for select to authenticated
  using ( public.ruolo_utente() is not null );

drop policy if exists cli_feedback_write on public.clienti_feedback;
create policy cli_feedback_write on public.clienti_feedback for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale','reception') )
  with check ( public.ruolo_utente() in ('amministratore','commerciale','reception') );

-- Fine migrazione v88.
