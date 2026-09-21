-- =====================================================================
--  MIGRAZIONE v100 - Non Conformità (ISO: MOD QA-10.2 + REG QA-10.2.1)
--
--  Registro delle non conformità. Ogni NC ha reparto/i, ambito/i (qualità/
--  ambiente), gravità 1-5, azione correttiva, esito. Da qui si generano
--  sia il RAPPORTO singolo (PDF/stampa) sia il REGISTRO (Excel con calcoli).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.non_conformita (
  id               uuid primary key default gen_random_uuid(),
  numero           int  not null default 0,           -- progressivo per anno
  anno             int  not null,
  data_rilevamento date not null default current_date,
  reparti          text[] default '{}',               -- Amministrativo/Commerciale/Forniture/Logistica/Operativo/Gestionale
  ambiti           text[] default '{}',               -- Qualità / Ambiente
  gravita          int,                                -- 1..5
  descrizione      text default '',
  azione_correttiva text default '',
  responsabile     text default '',
  data_limite      date,
  esito            text,                               -- 'positivo' | 'negativo' | null (in corso)
  note             text default '',
  commessa_id      uuid references public.commesse(id) on delete set null,  -- eventuale legame a una commessa
  creato_da        uuid references public.profiles(id),
  creato_il        timestamptz not null default now()
);
create index if not exists idx_nc_anno on public.non_conformita(anno);

alter table public.non_conformita enable row level security;
drop policy if exists nc_select on public.non_conformita;
create policy nc_select on public.non_conformita for select to authenticated
  using ( public.ruolo_utente() is not null );
drop policy if exists nc_write on public.non_conformita;
create policy nc_write on public.non_conformita for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') )
  with check ( public.ruolo_utente() in ('amministratore','commerciale') );

-- Fine migrazione v100.
