-- =====================================================================
--  Migrazione v156 — Allegati del PREVENTIVO (firmato, ODA, grafiche, ecc.)
--  File caricati nel bucket Storage "commesse-file" (riusato, path "preventivi/…")
--  o link alla cartella server. Categoria per capire cos'è ogni file.
--  Economici only.
-- =====================================================================

create table if not exists public.preventivi_file (
  id            uuid primary key default gen_random_uuid(),
  preventivo_id uuid not null references public.preventivi (id) on delete cascade,
  tipo          text not null default 'file' check (tipo in ('file','link')),
  categoria     text default 'altro',          -- grafica | firmato | oda | altro
  nome          text default '',
  path          text,
  url           text,
  caricato_da   uuid,
  caricato_il   timestamptz not null default now()
);
create index if not exists prevfile_idx on public.preventivi_file (preventivo_id);

alter table public.preventivi_file enable row level security;
drop policy if exists prevfile_all on public.preventivi_file;
create policy prevfile_all on public.preventivi_file for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v156.
