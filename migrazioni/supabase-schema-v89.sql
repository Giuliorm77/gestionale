-- =====================================================================
--  MIGRAZIONE v89 - Registro valutazione fornitori (ISO REG QA-8.4)
--
--  Valutazione periodica del fornitore su 5 criteri (scala 1-4):
--  Qualità, Prezzo, Tempi, Ecosostenibilità, Disponibilità.
--  Media dei 5 -> Qualifica: media >= 3 = Qualificato, altrimenti No.
--  Storico datato (l'ISO chiede il riesame almeno ogni 2 anni); il
--  registro/export usa l'ultima valutazione per fornitore.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.fornitori_valutazioni (
  id              uuid primary key default gen_random_uuid(),
  fornitore_id    uuid references public.fornitori(id) on delete cascade,
  fornitore_nome  text default '',                 -- snapshot ragione sociale
  data_valutazione date not null default current_date,
  qualita         int,
  prezzo          int,
  tempi           int,
  ecosostenibilita int,
  disponibilita   int,
  note            text default '',
  creato_da       uuid references public.profiles(id),
  creato_il       timestamptz not null default now()
);
create index if not exists idx_forn_val_forn on public.fornitori_valutazioni(fornitore_id);
create index if not exists idx_forn_val_data on public.fornitori_valutazioni(data_valutazione);

alter table public.fornitori_valutazioni enable row level security;

drop policy if exists forn_val_select on public.fornitori_valutazioni;
create policy forn_val_select on public.fornitori_valutazioni for select to authenticated
  using ( public.ruolo_utente() is not null );

drop policy if exists forn_val_write on public.fornitori_valutazioni;
create policy forn_val_write on public.fornitori_valutazioni for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') )
  with check ( public.ruolo_utente() in ('amministratore','commerciale') );

-- Fine migrazione v89.
