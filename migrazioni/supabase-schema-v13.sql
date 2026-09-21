-- =====================================================================
--  MIGRAZIONE v13 - PREVENTIVI (modulo commerciale centrale, 5.5)
--  Testata + righe. Le percentuali (spese generali, IVA, soglia margine)
--  vengono "congelate" sul preventivo, cosi' i preventivi vecchi restano
--  coerenti anche se in futuro cambi le Impostazioni.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.preventivi (
  id                 uuid primary key default gen_random_uuid(),
  numero             text default '',
  cliente_id         uuid references public.clienti (id),
  cliente_nome       text default '',                 -- copia della ragione sociale
  data               date not null default current_date,
  validita_giorni    int default 30,
  riferimento        text default '',
  stato              text not null default 'bozza'
                     check (stato in ('bozza','inviato','accettato','rifiutato')),
  imballaggio        numeric(12,2) default 0,         -- a carico cliente
  trasporto          numeric(12,2) default 0,         -- a carico cliente
  spese_generali_pct numeric default 0,               -- snapshot da impostazioni
  iva_pct            numeric default 22,              -- snapshot
  margine_minimo_pct numeric default 0,               -- snapshot (soglia avviso)
  note               text default '',
  condizioni         text default '',
  creato_da          uuid references auth.users (id),
  creato_il          timestamptz not null default now(),
  aggiornato_il      timestamptz not null default now()
);

create table if not exists public.preventivi_righe (
  id              uuid primary key default gen_random_uuid(),
  preventivo_id   uuid not null references public.preventivi (id) on delete cascade,
  ordine          int default 0,
  tipo            text not null default 'materiale'
                  check (tipo in ('materiale','manodopera','impianto','altro')),
  descrizione     text default '',
  articolo_id     uuid references public.articoli (id),
  lavorazione     text default '',
  quantita        numeric(12,2) default 1,      -- materiale = pezzi; manodopera = ore
  unita           text default '',
  costo_unitario  numeric(12,2) default 0,      -- costo interno unitario (per il margine)
  prezzo_unitario numeric(12,2) default 0,      -- prezzo di vendita unitario
  sconto_pct      numeric default 0
);
create index if not exists righe_prev_idx on public.preventivi_righe (preventivo_id);

-- RLS: modulo commerciale -> amministratore e commerciale
alter table public.preventivi       enable row level security;
alter table public.preventivi_righe enable row level security;

drop policy if exists preventivi_all on public.preventivi;
create policy preventivi_all on public.preventivi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists righe_all on public.preventivi_righe;
create policy righe_all on public.preventivi_righe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v13.
