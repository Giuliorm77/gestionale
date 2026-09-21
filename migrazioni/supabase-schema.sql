-- =====================================================================
--  GESTIONALE STAMPA & ALLESTIMENTI - Schema database Supabase
--  Modulo 1: Anagrafica Clienti + Ruoli/Permessi
--
--  COME USARE:
--  1. Vai su https://supabase.com -> crea un progetto
--  2. Menu di sinistra: "SQL Editor" -> "New query"
--  3. Incolla TUTTO questo file e premi "Run"
--  4. Segui le note finali per creare il primo Amministratore
-- =====================================================================

-- ---------------------------------------------------------------------
-- PROFILI UTENTE (collegati agli utenti di autenticazione Supabase)
-- Ruoli previsti: amministratore, commerciale, produzione, reception
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  nome       text not null default '',
  ruolo      text not null default 'reception'
             check (ruolo in ('amministratore','commerciale','produzione','reception')),
  creato_il  timestamptz not null default now()
);

-- Funzione di supporto: restituisce il ruolo dell'utente collegato.
-- security definer -> puo leggere profiles anche dentro le policy senza ricorsione.
create or replace function public.ruolo_utente()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select ruolo from public.profiles where id = auth.uid();
$$;

-- Alla registrazione di un nuovo utente creo automaticamente il suo profilo
-- (ruolo iniziale "reception"; l'amministratore poi lo modifica).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nome, ruolo)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)),
    'reception'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- LISTINI (modulo futuro: qui solo la tabella, si popolera piu avanti)
-- ---------------------------------------------------------------------
create table if not exists public.listini (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  descrizione text default '',
  attivo      boolean not null default true,
  creato_il   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- CLIENTI (dati anagrafici e fiscali, senza dati economici sensibili)
-- ---------------------------------------------------------------------
create table if not exists public.clienti (
  id             uuid primary key default gen_random_uuid(),
  ragione_sociale text not null,
  tipo_attivita   text default '',        -- testo libero
  partita_iva     text default '',
  codice_fiscale  text default '',
  codice_sdi      text default '',
  telefono        text default '',
  cellulare       text default '',
  lavorazioni     text[] not null default '{}',
  note            text default '',
  creato_il       timestamptz not null default now(),
  creato_da       uuid references auth.users (id)
);

-- SEDI: piu sedi per cliente, ognuna con un tipo
create table if not exists public.clienti_sedi (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clienti (id) on delete cascade,
  tipo        text not null default 'operativa'
              check (tipo in ('legale','operativa','destinazione_merce')),
  indirizzo   text default '',
  cap         text default '',
  citta       text default '',
  provincia   text default '',
  nazione     text default 'Italia'
);

-- EMAIL: piu email per cliente, categorizzate (nessun limite di numero)
create table if not exists public.clienti_email (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clienti (id) on delete cascade,
  categoria   text not null default 'generica'
              check (categoria in ('amministrazione','commerciale','generica','pec','ordini')),
  indirizzo   text not null
);

-- CONDIZIONI COMMERCIALI (dati economici SENSIBILI, tabella separata).
-- Sta in una tabella a parte proprio per poterla proteggere lato server:
-- solo amministratore e commerciale possono leggerla/scriverla.
create table if not exists public.clienti_condizioni (
  cliente_id         uuid primary key references public.clienti (id) on delete cascade,
  listino_id         uuid references public.listini (id),
  sconto_percentuale numeric(5,2) default 0,
  fatturato          numeric(14,2) default 0,
  aggiornato_il      timestamptz not null default now()
);

-- =====================================================================
--  ROW LEVEL SECURITY (i permessi VERI, applicati dal database)
-- =====================================================================
alter table public.profiles           enable row level security;
alter table public.listini            enable row level security;
alter table public.clienti            enable row level security;
alter table public.clienti_sedi       enable row level security;
alter table public.clienti_email      enable row level security;
alter table public.clienti_condizioni enable row level security;

-- --- PROFILES ---
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.ruolo_utente() = 'amministratore');

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (public.ruolo_utente() = 'amministratore')
  with check (public.ruolo_utente() = 'amministratore');

-- --- LISTINI ---
drop policy if exists listini_select on public.listini;
create policy listini_select on public.listini for select to authenticated
  using (true);

drop policy if exists listini_write on public.listini;
create policy listini_write on public.listini for all to authenticated
  using (public.ruolo_utente() = 'amministratore')
  with check (public.ruolo_utente() = 'amministratore');

-- --- CLIENTI ---
drop policy if exists clienti_select on public.clienti;
create policy clienti_select on public.clienti for select to authenticated
  using (true);

drop policy if exists clienti_insert on public.clienti;
create policy clienti_insert on public.clienti for insert to authenticated
  with check (public.ruolo_utente() in ('amministratore','commerciale','reception'));

drop policy if exists clienti_update on public.clienti;
create policy clienti_update on public.clienti for update to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists clienti_delete on public.clienti;
create policy clienti_delete on public.clienti for delete to authenticated
  using (public.ruolo_utente() = 'amministratore');

-- --- SEDI (seguono i permessi di scrittura dei clienti) ---
drop policy if exists sedi_select on public.clienti_sedi;
create policy sedi_select on public.clienti_sedi for select to authenticated
  using (true);

drop policy if exists sedi_write on public.clienti_sedi;
create policy sedi_write on public.clienti_sedi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','reception'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','reception'));

-- --- EMAIL ---
drop policy if exists email_select on public.clienti_email;
create policy email_select on public.clienti_email for select to authenticated
  using (true);

drop policy if exists email_write on public.clienti_email;
create policy email_write on public.clienti_email for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','reception'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','reception'));

-- --- CONDIZIONI COMMERCIALI (solo ruoli economici) ---
drop policy if exists condizioni_select on public.clienti_condizioni;
create policy condizioni_select on public.clienti_condizioni for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists condizioni_write on public.clienti_condizioni;
create policy condizioni_write on public.clienti_condizioni for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- =====================================================================
--  DATI DI ESEMPIO (listini segnaposto per il futuro modulo Listini)
-- =====================================================================
insert into public.listini (nome, descrizione) values
  ('Listino Base',    'Prezzi standard'),
  ('Listino Rivenditori', 'Sconto rivenditori'),
  ('Listino Agenzie', 'Condizioni riservate agenzie')
on conflict do nothing;

-- =====================================================================
--  ULTIMO PASSO -> CREA IL PRIMO AMMINISTRATORE
--  1. Nell'app registra un utente con la tua email (schermata Login)
--  2. Torna qui nel SQL Editor ed esegui, con la TUA email:
--
--     update public.profiles set ruolo = 'amministratore'
--     where id = (select id from auth.users where email = 'tua@email.it');
--
--  Da quel momento potrai cambiare i ruoli degli altri utenti dall'app.
-- =====================================================================
