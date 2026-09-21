-- =====================================================================
--  MIGRAZIONE v90 - Registro controllo mezzi e strumenti (ISO REG QA-7.1.3)
--
--  Anagrafica strumenti/mezzi con piano di controllo (tipo, chi, frequenza
--  in mesi) + storico dei controlli effettuati dagli operatori. Lo stato
--  (Ok / In scadenza / Scaduto) e l'Excel ISO si generano in automatico
--  dall'ultima data di controllo + frequenza.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- Anagrafica strumenti/mezzi (piano di controllo)
create table if not exists public.strumenti (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null,
  codice         text default '',                  -- targa/matricola o "non applicabile"
  tipo_controllo text default '',                  -- es. pulizia, taratura, tagliando
  chi_controlla  text default '',
  frequenza_mesi int default 0,
  attivo         boolean not null default true,
  note           text default '',
  creato_da      uuid references public.profiles(id),
  creato_il      timestamptz not null default now()
);

-- Storico controlli effettuati (chi/quando)
create table if not exists public.strumenti_controlli (
  id           uuid primary key default gen_random_uuid(),
  strumento_id uuid references public.strumenti(id) on delete cascade,
  data         date not null default current_date,
  operatore    text default '',
  esito        text default 'Ok',
  note         text default '',
  creato_da    uuid references public.profiles(id),
  creato_il    timestamptz not null default now()
);
create index if not exists idx_strum_ctrl_strum on public.strumenti_controlli(strumento_id);
create index if not exists idx_strum_ctrl_data  on public.strumenti_controlli(data);

alter table public.strumenti enable row level security;
alter table public.strumenti_controlli enable row level security;

-- Lettura: ruoli operativi. Scrittura anagrafica: amm/commerciale/magazzino.
drop policy if exists strumenti_select on public.strumenti;
create policy strumenti_select on public.strumenti for select to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino') );
drop policy if exists strumenti_write on public.strumenti;
create policy strumenti_write on public.strumenti for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale','magazzino') )
  with check ( public.ruolo_utente() in ('amministratore','commerciale','magazzino') );

-- Controlli: registrabili anche dagli operatori di produzione.
drop policy if exists strum_ctrl_select on public.strumenti_controlli;
create policy strum_ctrl_select on public.strumenti_controlli for select to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino') );
drop policy if exists strum_ctrl_write on public.strumenti_controlli;
create policy strum_ctrl_write on public.strumenti_controlli for all to authenticated
  using ( public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino') )
  with check ( public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino') );

-- Fine migrazione v90.
