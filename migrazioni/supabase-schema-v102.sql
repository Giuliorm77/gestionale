-- =====================================================================
--  MIGRAZIONE v102 - Piano progettazione (MOD QA-8.3) +
--                    Pianificazione e Controlli Servizio-Produzione (DOC QA-8.1.1)
--
--  Due schede ISO legate (facoltativamente) a una commessa. Da qui si genera
--  il documento stampabile (PDF).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- --- MOD QA-8.3 Piano di Progettazione e Sviluppo ---
create table if not exists public.progetti_piano (
  id            uuid primary key default gen_random_uuid(),
  commessa_id   uuid references public.commesse(id) on delete set null,
  nome_progetto text not null default '',
  obiettivi     text default '',
  cliente       text default '',
  personale     text default '',
  data_inizio   date,
  durata        text default '',
  input_prog    text default '',            -- lista input (una voce per riga)
  output_prog   text default '',            -- lista output (una voce per riga)
  riesame_responsabile text default '', riesame_data date, riesame_esito text default '',
  verifica_responsabile text default '', verifica_data date, verifica_esito text default '',
  validazione_responsabile text default '', validazione_data date, validazione_esito text default '',
  modifiche_data date, modifiche_esito text default '', modifiche_azioni text default '',
  note          text default '',
  creato_da     uuid references public.profiles(id),
  creato_il     timestamptz not null default now()
);

-- --- DOC QA-8.1.1 Pianificazione e Controlli Servizio-Produzione ---
create table if not exists public.pianificazioni_produzione (
  id               uuid primary key default gen_random_uuid(),
  commessa_id      uuid references public.commesse(id) on delete set null,
  servizio_prodotto text not null default '',
  risorse_umane    text default '',
  materie_prime    text default '',
  certificazioni   text default '',
  attrezzature     text default '',
  automezzi        text default '',
  fasi             jsonb default '[]',        -- [{fase, controllo, responsabile, frequenza}]
  note             text default '',
  creato_da        uuid references public.profiles(id),
  creato_il        timestamptz not null default now()
);

alter table public.progetti_piano enable row level security;
alter table public.pianificazioni_produzione enable row level security;

drop policy if exists pp_select on public.progetti_piano;
create policy pp_select on public.progetti_piano for select to authenticated using ( public.ruolo_utente() is not null );
drop policy if exists pp_write on public.progetti_piano;
create policy pp_write on public.progetti_piano for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') ) with check ( public.ruolo_utente() in ('amministratore','commerciale') );

drop policy if exists pipr_select on public.pianificazioni_produzione;
create policy pipr_select on public.pianificazioni_produzione for select to authenticated using ( public.ruolo_utente() is not null );
drop policy if exists pipr_write on public.pianificazioni_produzione;
create policy pipr_write on public.pianificazioni_produzione for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale') ) with check ( public.ruolo_utente() in ('amministratore','commerciale') );

-- Fine migrazione v102.
