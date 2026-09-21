-- =====================================================================
--  MIGRAZIONE v17 - LAVORAZIONI gestibili (anagrafica di base, 5.9)
--  L'elenco delle lavorazioni diventa una tabella modificabile dall'app,
--  usata in tutto il gestionale.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.lavorazioni (
  id        uuid primary key default gen_random_uuid(),
  nome      text not null unique,
  attivo    boolean not null default true,
  ordine    int default 0,
  creato_il timestamptz not null default now()
);

-- Popolo con le lavorazioni attuali (solo se non gia' presenti)
insert into public.lavorazioni (nome, ordine) values
  ('Stampa digitale piccolo formato',1),
  ('Stampa digitale grande formato',2),
  ('Serigrafia',3),
  ('Gadget',4),
  ('Allestimenti eventi',5),
  ('Scenografie polistirolo',6),
  ('Insegne luminose',7),
  ('Cartotecnica',8),
  ('Packaging',9)
on conflict (nome) do nothing;

alter table public.lavorazioni enable row level security;

-- Lettura: tutti gli utenti approvati (serve nei menu di clienti, catalogo, ecc.)
drop policy if exists lavorazioni_select on public.lavorazioni;
create policy lavorazioni_select on public.lavorazioni for select to authenticated
  using (public.ruolo_utente() is not null);

-- Modifica: amministratore e commerciale
drop policy if exists lavorazioni_write on public.lavorazioni;
create policy lavorazioni_write on public.lavorazioni for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v17.
