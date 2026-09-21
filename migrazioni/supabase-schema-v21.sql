-- =====================================================================
--  MIGRAZIONE v21 - IMBALLI (ricette di imballaggio, 5.9)
--  Ogni imballo e' una ricetta di componenti (pluriball, nastro, pedana,
--  tempo...), ognuno con il suo modo di calcolo e costo.
--  Livello: per prodotto/pezzo oppure per spedizione/ordine.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.imballi (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  livello       text not null default 'prodotto' check (livello in ('prodotto','ordine')),
  unita_calcolo text not null default 'mq' check (unita_calcolo in ('mq','mtl','mc','pz')),
  ricarico_pct  numeric default 0,   -- eventuale ricarico % sul costo dell'imballo
  attivo        boolean not null default true,
  note          text default '',
  ordine        int default 0,
  creato_il     timestamptz not null default now()
);

create table if not exists public.imballi_voci (
  id          uuid primary key default gen_random_uuid(),
  imballo_id  uuid not null references public.imballi (id) on delete cascade,
  descrizione text not null default '',
  modo        text not null default 'mq' check (modo in ('mq','mtl','mc','pz','fisso','ora')),
  costo       numeric(12,2) default 0,
  ordine      int default 0
);
create index if not exists imbvoci_idx on public.imballi_voci (imballo_id);

alter table public.imballi      enable row level security;
alter table public.imballi_voci enable row level security;

drop policy if exists imballi_all on public.imballi;
create policy imballi_all on public.imballi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists imballi_voci_all on public.imballi_voci;
create policy imballi_voci_all on public.imballi_voci for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v21.
