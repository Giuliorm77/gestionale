-- =====================================================================
--  MIGRAZIONE v5 - CATALOGO unico "Prodotti e Servizi"
--  Cuore del sistema: ci si agganceranno Magazzino, Preventivi, E-commerce.
--
--  tipo = 'prodotto' (gadget: dimensioni, imballi, giacenza, foto...)
--       | 'servizio' (stampa/allestimenti: unita a mq/ml/ora, prezzi)
--  3 livelli di prezzo su ogni articolo: rivenditori / pubblico / riservato.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.articoli (
  id                   uuid primary key default gen_random_uuid(),
  tipo                 text not null default 'prodotto' check (tipo in ('prodotto','servizio')),

  -- Identificazione
  codice               text default '',
  articolo_padre       text default '',
  nome_articolo        text not null default '',
  descrizione_articolo text default '',
  categoria            text default '',
  settore              text default '',
  lavorazione          text default '',   -- per i servizi (collega alle lavorazioni)

  -- Caratteristiche (prodotto)
  dimensione_articolo  text default '',
  materiale_articolo   text default '',
  colore_articolo      text default '',
  deco_colore_articolo text default '',
  taglia_articolo      text default '',
  peso_articolo        text default '',
  unita                text default '',   -- mq, ml, ora, cad...

  -- Imballo (carton)
  dimensione_1_carton  text default '',
  dimensione_2_carton  text default '',
  dimensione_3_carton  text default '',
  volume_carton        text default '',
  inner_carton         text default '',
  box_carton           text default '',
  export_carton        text default '',

  -- Prezzi (3 livelli)
  prezzo_rivenditori   numeric(12,2) default 0,
  prezzo_pubblico      numeric(12,2) default 0,
  prezzo_riservato     numeric(12,2) default 0,

  -- Magazzino (predisposto; il modulo carico/scarico sara' la Fase 2)
  giacenza             numeric(12,2) default 0,

  -- Media / catalogo
  link_foto            text default '',
  foto                 text default '',
  catalogo             text default '',

  attivo               boolean not null default true,
  note                 text default '',
  aggiornato_il        timestamptz not null default now(),
  creato_il            timestamptz not null default now(),
  creato_da            uuid references auth.users (id)
);

-- Ricerche piu' rapide
create index if not exists articoli_nome_idx     on public.articoli (nome_articolo);
create index if not exists articoli_categoria_idx on public.articoli (categoria);
create index if not exists articoli_tipo_idx      on public.articoli (tipo);

-- =====================================================================
--  RLS - il catalogo contiene prezzi = dati economici
--  Lettura e scrittura: amministratore e commerciale.
-- =====================================================================
alter table public.articoli enable row level security;

drop policy if exists articoli_select on public.articoli;
create policy articoli_select on public.articoli for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists articoli_write on public.articoli;
create policy articoli_write on public.articoli for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v5.
