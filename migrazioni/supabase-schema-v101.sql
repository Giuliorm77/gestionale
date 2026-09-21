-- =====================================================================
--  MIGRAZIONE v101 - Registro controlli operativi qualità (ISO REG QA-8.5.1)
--
--  Registra i controlli qualità effettuati su commesse/attività/processi:
--  cosa è stato controllato, da chi, con quale esito e quando. Da qui si
--  genera il registro Excel (con calcoli per anno).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.controlli_qualita (
  id                uuid primary key default gen_random_uuid(),
  commessa_processo text not null default '',        -- Commessa / Attività / Processo controllato
  controllo         text default '',                 -- descrizione del controllo effettuato
  chi               text default '',                  -- chi ha effettuato il controllo
  esito             text default 'Positivo'           -- Positivo | Parzialmente positivo | Negativo
                    check (esito in ('Positivo','Parzialmente positivo','Negativo')),
  data              date not null default current_date,
  anno              int  not null,
  note              text default '',
  commessa_id       uuid references public.commesse(id) on delete set null,
  creato_da         uuid references public.profiles(id),
  creato_il         timestamptz not null default now()
);
create index if not exists idx_cq_anno on public.controlli_qualita(anno);

alter table public.controlli_qualita enable row level security;
drop policy if exists cq_select on public.controlli_qualita;
create policy cq_select on public.controlli_qualita for select to authenticated
  using ( public.ruolo_utente() is not null );
drop policy if exists cq_write on public.controlli_qualita;
create policy cq_write on public.controlli_qualita for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') )
  with check ( public.ruolo_utente() in ('amministratore','commerciale') );

-- Fine migrazione v101.
