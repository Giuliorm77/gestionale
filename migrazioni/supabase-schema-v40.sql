-- =====================================================================
--  MIGRAZIONE v40 - LISTINO FORNITORI per articolo (chi lo vende e a quanto)
--
--  Per ogni articolo, l'elenco dei fornitori che lo trattano con il loro
--  prezzo d'acquisto e codice. Serve al confronto prezzi ("miglior prezzo")
--  e, in seguito, al generatore ordini da commessa.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.articoli_fornitori (
  id                uuid primary key default gen_random_uuid(),
  articolo_id       uuid not null references public.articoli (id) on delete cascade,
  fornitore_id      uuid not null references public.fornitori (id) on delete cascade,
  prezzo            numeric(12,2) default 0,     -- prezzo d'acquisto
  codice_fornitore  text default '',             -- codice articolo del fornitore
  lead_time_giorni  int,                          -- giorni di consegna (facolt.)
  minimo_ordine     numeric(12,2),                -- quantità/importo minimo (facolt.)
  note              text default ''
);
create index if not exists artforn_articolo_idx on public.articoli_fornitori (articolo_id);
create index if not exists artforn_fornitore_idx on public.articoli_fornitori (fornitore_id);

-- RLS: come catalogo/fornitori -> amministratore e commerciale
alter table public.articoli_fornitori enable row level security;

drop policy if exists articoli_fornitori_all on public.articoli_fornitori;
create policy articoli_fornitori_all on public.articoli_fornitori for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v40.
