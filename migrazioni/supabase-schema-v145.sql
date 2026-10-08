-- =====================================================================
--  Migrazione v145 — Scadenzario (cache locale delle scadenze da Fatture in Cloud)
--  Sola lettura da FIC: la edge function "fic-sync" scarica le fatture emesse
--  (clienti) e ricevute (fornitori) con le loro RATE/scadenze e le scrive qui.
--  Una riga = UNA scadenza (una fattura può avere più rate).
--  Dato economico → visibile solo ad amministratore + Back office (commerciale).
--  Additiva e reversibile.
-- =====================================================================

create table if not exists public.scadenze (
  id               uuid primary key default gen_random_uuid(),
  tipo             text not null check (tipo in ('cliente','fornitore')),
  fic_doc_id       bigint,                 -- id documento in Fatture in Cloud
  fic_payment_id   bigint,                 -- id della singola rata/scadenza (univoco)
  numero           text default '',
  data_documento   date,
  controparte_nome text default '',        -- nome cliente/fornitore come in FIC
  controparte_piva text default '',
  cliente_id       uuid references public.clienti (id),     -- mappatura (best effort, Fase 2)
  fornitore_id     uuid references public.fornitori (id),
  commessa_id      uuid references public.commesse (id),
  importo          numeric(12,2) default 0,  -- importo della rata
  data_scadenza    date,
  pagato           boolean not null default false,
  data_pagamento   date,
  metodo           text default '',
  valuta           text default 'EUR',
  note             text default '',
  aggiornato_il    timestamptz not null default now()
);
create unique index if not exists scad_ficpay_uidx on public.scadenze (fic_payment_id) where fic_payment_id is not null;
create index if not exists scad_tipo_idx on public.scadenze (tipo);
create index if not exists scad_scad_idx on public.scadenze (data_scadenza);
create index if not exists scad_cli_idx  on public.scadenze (cliente_id);
create index if not exists scad_for_idx  on public.scadenze (fornitore_id);

alter table public.scadenze enable row level security;
drop policy if exists scad_econ on public.scadenze;
create policy scad_econ on public.scadenze for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));
-- la edge function scrive con la service_role (bypassa RLS).

-- stato dell'ultima sincronizzazione (una riga)
create table if not exists public.scadenze_sync (
  id            int primary key default 1 check (id=1),
  ultimo_sync   timestamptz,
  esito         text default '',
  n_clienti     int default 0,
  n_fornitori   int default 0
);
insert into public.scadenze_sync (id) values (1) on conflict (id) do nothing;
alter table public.scadenze_sync enable row level security;
drop policy if exists scadsync_econ on public.scadenze_sync;
create policy scadsync_econ on public.scadenze_sync for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v145.
-- (Per annullare: drop table public.scadenze; drop table public.scadenze_sync;)
