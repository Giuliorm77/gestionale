-- =====================================================================
--  MIGRAZIONE v56 - AGENTI / RAPPRESENTANTI + classificazione cliente
--
--  Aggiunge:
--   1) tabella `agenti` (anagrafica rappresentanti, con % provvigione standard)
--   2) su `clienti`: categoria (Cliente finale / Rivenditore), agente assegnato,
--      ed eventuale % provvigione di ECCEZIONE per quel cliente (NULL = usa
--      quella standard dell'agente).
--
--  Le provvigioni si calcoleranno (Stage B) sulle commesse; a regime la base
--  passera' all'INCASSATO quando ci saranno Fatturazione + Scadenzario.
--
--  Dati economici -> visibili/gestibili solo da amministratore e commerciale
--  (come fornitori). La produzione NON vede gli agenti.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELLA AGENTI
-- ---------------------------------------------------------------------
create table if not exists public.agenti (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email text,
  telefono text,
  provvigione_pct numeric default 0,          -- % standard dell'agente
  attivo boolean default true,
  note text,
  creato_da uuid,
  creato_il timestamptz default now(),
  aggiornato_il timestamptz default now()
);

alter table public.agenti enable row level security;

drop policy if exists agenti_select on public.agenti;
create policy agenti_select on public.agenti for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists agenti_write on public.agenti;
create policy agenti_write on public.agenti for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---------------------------------------------------------------------
-- 2. CLIENTI: classificazione + agente assegnato + % di eccezione
-- ---------------------------------------------------------------------
alter table public.clienti add column if not exists categoria text default 'Cliente finale';
alter table public.clienti add column if not exists agente_id uuid references public.agenti(id) on delete set null;
alter table public.clienti add column if not exists provvigione_pct numeric;   -- NULL = usa quella dell'agente

-- Fine migrazione v56.
