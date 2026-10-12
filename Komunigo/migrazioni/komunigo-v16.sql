-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v16  (catalogo fornitore: New Wave / Clique)
--
--  Tabelle di APPOGGIO dove la edge function "catalogo-fornitore" scarica il
--  catalogo del fornitore (export JSON del portale NWG): prodotti, varianti
--  colore e SKU (taglia) con prezzo netto rivenditore e listino.
--  Dal gestionale (modulo "Catalogo fornitori") lo staff sceglie quali
--  prodotti proporre su Komunigo e con quale ricarico sul netto.
--
--  NON tocca il negozio né il listino: i dati restano SOLO interni
--  (prezzo netto = dato economico → visibile solo ad amministratore + Back office).
--  Additiva e reversibile. Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

-- PRODOTTO (es. "Basic-T", codice 029030)
create table if not exists public.catalogo_fornitore_prodotti (
  id               uuid primary key default gen_random_uuid(),
  fornitore        text not null,              -- 'newwave'
  codice           text not null,              -- productNumber
  nome             text default '',
  brand            text default '',
  categoria        text default '',            -- es. "Parti superiori;T-shirt"
  descrizione      text default '',
  testo_catalogo   text default '',
  linea            text default '',            -- productCommerceText (es. "Basic")
  genere           text default '',
  vestibilita      text default '',
  tessuto          text default '',
  grammatura       text default '',            -- es. "145 g/m2"
  taglie           text default '',            -- es. "XS–4XL"
  lavaggio         text default '',
  tecnica          text default '',            -- productMaterialTechnique
  note_tecnica     text default '',            -- productTechniqueComment
  codice_stampa    text default '',            -- productPrintCode
  disponibile_dal  text default '',            -- availableFrom
  immagini         jsonb not null default '[]'::jsonb,
  attivo           boolean not null default true,   -- presente nell'ultimo feed
  -- scelte dello staff (la sync NON le sovrascrive)
  selezionato      boolean not null default false,  -- da proporre su Komunigo
  ricarico_pct     numeric(7,2),                    -- null = ricarico predefinito
  note             text default '',
  aggiornato_il    timestamptz not null default now(),
  creato_il        timestamptz not null default now(),
  constraint catfor_prod_uq unique (fornitore, codice)
);

-- VARIANTE COLORE (es. 029030-00 bianco)
create table if not exists public.catalogo_fornitore_varianti (
  id               uuid primary key default gen_random_uuid(),
  fornitore        text not null,
  codice           text not null,              -- productNumber-colorCode
  codice_prodotto  text not null,
  codice_colore    text default '',
  colore           text default '',
  immagini         jsonb not null default '[]'::jsonb,
  ordine           int default 0,
  attivo           boolean not null default true,
  aggiornato_il    timestamptz not null default now(),
  constraint catfor_var_uq unique (fornitore, codice)
);
create index if not exists catfor_var_prod_idx on public.catalogo_fornitore_varianti (fornitore, codice_prodotto);

-- SKU = colore + taglia (es. 029030-00-4 = bianco S)
create table if not exists public.catalogo_fornitore_sku (
  id               uuid primary key default gen_random_uuid(),
  fornitore        text not null,
  sku              text not null,
  codice_prodotto  text not null,
  codice_colore    text default '',
  taglia           text default '',            -- name (XS, S, M…)
  codice_taglia    text default '',            -- size (ordine taglie)
  ordine           int default 0,
  ean              text default '',
  prezzo_netto     numeric(12,2),              -- customerPrice: il NOSTRO costo
  prezzo_listino   numeric(12,2),              -- retailPrice: listino al pubblico
  pezzi_cartone    int,
  lead_time        int,
  giacenza         int,                        -- in attesa del feed giacenze
  attivo           boolean not null default true,
  aggiornato_il    timestamptz not null default now(),
  constraint catfor_sku_uq unique (fornitore, sku)
);
create index if not exists catfor_sku_prod_idx on public.catalogo_fornitore_sku (fornitore, codice_prodotto);

-- stato dell'ultima sincronizzazione + ricarico predefinito (una riga per fornitore)
create table if not exists public.catalogo_fornitore_sync (
  fornitore        text primary key,
  nome             text default '',
  ultimo_sync      timestamptz,
  esito            text default '',
  n_prodotti       int default 0,
  n_varianti       int default 0,
  n_sku            int default 0,
  ricarico_default numeric(7,2) not null default 100   -- % sul netto
);
insert into public.catalogo_fornitore_sync (fornitore, nome) values ('newwave','New Wave Italia')
  on conflict (fornitore) do nothing;

-- RIEPILOGO per la lista del gestionale (un rigo per prodotto, senza scaricare 10.000 SKU)
drop view if exists public.catalogo_fornitore_riepilogo;
create view public.catalogo_fornitore_riepilogo
with (security_invoker = true) as
select p.*,
  (select count(*) from public.catalogo_fornitore_varianti v
     where v.fornitore=p.fornitore and v.codice_prodotto=p.codice and v.attivo)       as n_colori,
  s.n_sku, s.netto_min, s.netto_max, s.listino_min, s.listino_max,
  s.n_listino_zero, s.n_netto_sopra_listino
from public.catalogo_fornitore_prodotti p
left join lateral (
  select count(*)                                              as n_sku,
         min(k.prezzo_netto)                                   as netto_min,
         max(k.prezzo_netto)                                   as netto_max,
         min(nullif(k.prezzo_listino,0))                       as listino_min,
         max(k.prezzo_listino)                                 as listino_max,
         count(*) filter (where coalesce(k.prezzo_listino,0)=0)               as n_listino_zero,
         count(*) filter (where k.prezzo_listino>0 and k.prezzo_netto>k.prezzo_listino) as n_netto_sopra_listino
  from public.catalogo_fornitore_sku k
  where k.fornitore=p.fornitore and k.codice_prodotto=p.codice and k.attivo
) s on true;

-- SICUREZZA: solo amministratore + Back office (commerciale). La edge function
-- scrive con la service_role (bypassa RLS). Nessun accesso anon.
alter table public.catalogo_fornitore_prodotti enable row level security;
alter table public.catalogo_fornitore_varianti enable row level security;
alter table public.catalogo_fornitore_sku      enable row level security;
alter table public.catalogo_fornitore_sync     enable row level security;

drop policy if exists catfor_prod_staff on public.catalogo_fornitore_prodotti;
create policy catfor_prod_staff on public.catalogo_fornitore_prodotti for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));
drop policy if exists catfor_var_staff on public.catalogo_fornitore_varianti;
create policy catfor_var_staff on public.catalogo_fornitore_varianti for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));
drop policy if exists catfor_sku_staff on public.catalogo_fornitore_sku;
create policy catfor_sku_staff on public.catalogo_fornitore_sku for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));
drop policy if exists catfor_sync_staff on public.catalogo_fornitore_sync;
create policy catfor_sync_staff on public.catalogo_fornitore_sync for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

revoke all on public.catalogo_fornitore_prodotti, public.catalogo_fornitore_varianti,
              public.catalogo_fornitore_sku, public.catalogo_fornitore_sync,
              public.catalogo_fornitore_riepilogo from anon;
grant select on public.catalogo_fornitore_riepilogo to authenticated;

-- Fine migrazione Komunigo v16.
-- (Per annullare: drop view public.catalogo_fornitore_riepilogo;
--  drop table public.catalogo_fornitore_sku, public.catalogo_fornitore_varianti,
--             public.catalogo_fornitore_prodotti, public.catalogo_fornitore_sync;)
