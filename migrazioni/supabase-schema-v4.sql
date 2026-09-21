-- =====================================================================
--  MIGRAZIONE v4 - Modulo LISTINI (elenchi prezzi + voci)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> New query -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

-- Campi extra sul listino (la tabella "listini" esiste gia')
alter table public.listini add column if not exists valuta text default 'EUR';
alter table public.listini add column if not exists note   text default '';

-- Voci del listino (le righe con i prezzi)
create table if not exists public.listini_voci (
  id           uuid primary key default gen_random_uuid(),
  listino_id   uuid not null references public.listini (id) on delete cascade,
  codice       text default '',
  descrizione  text not null default '',
  lavorazione  text default '',
  unita        text default '',
  prezzo       numeric(12,2) default 0,
  note         text default '',
  ordine       int default 0,
  creato_il    timestamptz not null default now()
);
alter table public.listini_voci enable row level security;

-- I listini contengono prezzi = dati economici -> gestibili da amministratore e commerciale
drop policy if exists listini_write on public.listini;
create policy listini_write on public.listini for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists listini_voci_select on public.listini_voci;
create policy listini_voci_select on public.listini_voci for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists listini_voci_write on public.listini_voci;
create policy listini_voci_write on public.listini_voci for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v4.
