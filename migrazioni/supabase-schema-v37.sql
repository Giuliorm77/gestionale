-- =====================================================================
--  MIGRAZIONE v37 - INTERVENTI / RILAVORAZIONI (post-vendita)
--
--  Un intervento è agganciato a una commessa (anche chiusa) e raccoglie le
--  righe di costo del reso/rilavorazione. Ogni riga ha:
--    - tipo (materiale/manodopera/trasporto/altro), quantità, COSTO (a noi)
--    - responsabilità: 'nostro' (a nostro carico) o 'cliente' (addebitabile)
--    - prezzo_addebito (se a carico cliente)
--    - se materiale con articolo: può scaricare dal magazzino
--  Dalle righe 'cliente' si genera il preventivo di addebito; il consuntivo
--  reale della commessa somma originale + interventi.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.interventi (
  id            uuid primary key default gen_random_uuid(),
  commessa_id   uuid not null references public.commesse (id) on delete cascade,
  numero        text default '',
  data          date not null default current_date,
  cliente_nome  text default '',
  motivo        text default '',
  stato         text not null default 'aperto' check (stato in ('aperto','chiuso')),
  note          text default '',
  creato_da     uuid references auth.users (id),
  creato_il     timestamptz not null default now(),
  aggiornato_il timestamptz not null default now()
);
create index if not exists interventi_commessa_idx on public.interventi (commessa_id);

create table if not exists public.interventi_righe (
  id              uuid primary key default gen_random_uuid(),
  intervento_id   uuid not null references public.interventi (id) on delete cascade,
  ordine          int default 0,
  tipo            text not null default 'materiale'
                  check (tipo in ('materiale','manodopera','trasporto','altro')),
  descrizione     text default '',
  articolo_id     uuid references public.articoli (id),
  operatore_id    uuid references public.operatori (id),
  quantita        numeric(12,2) default 1,
  unita           text default '',
  costo_unitario  numeric(12,2) default 0,        -- costo per noi
  responsabilita  text not null default 'nostro' check (responsabilita in ('nostro','cliente')),
  prezzo_addebito numeric(12,2) default 0,        -- prezzo al cliente (se responsabilita='cliente')
  scaricato       boolean default false,
  movimento_id    uuid references public.movimenti_magazzino (id)
);
create index if not exists interventi_righe_idx on public.interventi_righe (intervento_id);

-- RLS: come catalogo/magazzino -> amministratore e commerciale
alter table public.interventi       enable row level security;
alter table public.interventi_righe enable row level security;

drop policy if exists interventi_all on public.interventi;
create policy interventi_all on public.interventi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists interventi_righe_all on public.interventi_righe;
create policy interventi_righe_all on public.interventi_righe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v37.
