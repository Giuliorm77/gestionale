-- =====================================================================
--  MIGRAZIONE v31 - ORDINI A FORNITORI (acquisti)
--  Ordine d'acquisto a un fornitore con righe. Alla ricezione della merce
--  l'app crea movimenti di CARICO in magazzino (aggiornano la giacenza).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.ordini_fornitore (
  id            uuid primary key default gen_random_uuid(),
  numero        text default '',
  fornitore_id  uuid references public.fornitori (id),
  fornitore_nome text default '',
  data          date not null default current_date,
  data_prevista date,                            -- consegna prevista dal fornitore
  stato         text not null default 'bozza'
                check (stato in ('bozza','inviato','confermato','ricevuto_parziale','ricevuto','annullato')),
  riferimento   text default '',
  commessa_id   uuid references public.commesse (id) on delete set null,  -- ordine legato a una commessa
  note          text default '',
  totale        numeric(12,2) default 0,         -- snapshot imponibile
  creato_da     uuid references auth.users (id),
  creato_il     timestamptz not null default now(),
  aggiornato_il timestamptz not null default now()
);

create table if not exists public.ordini_fornitore_righe (
  id                uuid primary key default gen_random_uuid(),
  ordine_id         uuid not null references public.ordini_fornitore (id) on delete cascade,
  ordine            int default 0,
  articolo_id       uuid references public.articoli (id),
  descrizione       text default '',
  quantita          numeric(12,2) default 0,
  unita             text default '',
  prezzo_unitario   numeric(12,2) default 0,      -- costo d'acquisto
  quantita_ricevuta numeric(12,2) default 0,      -- gia' caricata a magazzino
  note              text default ''
);
create index if not exists ofr_ordine_idx on public.ordini_fornitore_righe (ordine_id);

-- RLS: come il catalogo/magazzino -> amministratore e commerciale
alter table public.ordini_fornitore       enable row level security;
alter table public.ordini_fornitore_righe enable row level security;

drop policy if exists of_all on public.ordini_fornitore;
create policy of_all on public.ordini_fornitore for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists ofr_all on public.ordini_fornitore_righe;
create policy ofr_all on public.ordini_fornitore_righe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v31.
