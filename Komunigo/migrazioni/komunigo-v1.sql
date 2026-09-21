-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v1  (e-commerce pubblico sullo STESSO database del gestionale)
--
--  COSA FA (tutto ADDITIVO: non tocca nessuna tabella o policy del gestionale):
--   1) crea VISTE pubbliche komunigo_* che espongono al ruolo `anon`
--      SOLO i campi sicuri (mai costi, margini, prezzi riservati);
--   2) crea le tabelle ordini komunigo_ordini / komunigo_ordini_righe,
--      scrivibili SOLO dal server (Edge Function con service_role), mai dal browser.
--
--  MODELLO DI SICUREZZA:
--   - Oggi un visitatore NON loggato (ruolo anon) non legge nulla del gestionale:
--     tutte le policy RLS richiedono ruolo_utente() IS NOT NULL. Restiamo cosi'.
--   - Le viste qui sotto sono di proprieta' di `postgres` e girano SENZA
--     security_invoker (default) -> bypassano la RLS della tabella base ma
--     mostrano solo la PROIEZIONE sicura (colonne scelte + filtro vendibile/attivo).
--     Quindi anon vede la vetrina, non i dati sensibili.
--   - I prezzi dei prodotti configurabili NON si calcolano nel browser: il sito
--     chiede il prezzo a una Edge Function (i costi/margini restano sul server).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. VETRINA PRODOTTI  (dallo stock reale del gestionale)
--    Solo articoli con flag vendibile = true. Espone prezzo_pubblico e la
--    disponibilita' reale (giacenza - impegnato). MAI costo/prezzo_riservato.
-- ---------------------------------------------------------------------
drop view if exists public.komunigo_prodotti;
create view public.komunigo_prodotti as
select
  a.id,
  a.codice,
  a.nome_articolo                              as nome,
  a.descrizione_articolo                       as descrizione,
  a.categoria,
  a.unita,
  a.prezzo_pubblico                            as prezzo,
  greatest(coalesce(a.giacenza,0) - coalesce(a.impegnato,0), 0) as disponibile,
  a.foto_urls
from public.articoli a
where a.vendibile = true;

comment on view public.komunigo_prodotti is
  'Vetrina e-commerce Komunigo: solo articoli vendibili, solo campi pubblici.';

-- ---------------------------------------------------------------------
-- 2. CONFIGURATORI  (lavorazioni su misura: forex, adesivi, striscioni...)
--    Espone quel che serve a COMPORRE la scelta (nomi, varianti, opzioni),
--    NON i costi. Il PREZZO arriva dalla Edge Function prezzo-configuratore.
-- ---------------------------------------------------------------------
drop view if exists public.komunigo_configuratori;
create view public.komunigo_configuratori as
select
  p.id,
  p.nome,
  p.unita_calcolo,
  p.minimo,
  p.note
from public.prodotti_config p
where p.attivo = true;

drop view if exists public.komunigo_configuratori_varianti;
create view public.komunigo_configuratori_varianti as
select
  v.id,
  v.prodotto_id,
  v.nome,
  v.spessore,
  v.ordine
from public.prodotti_config_varianti v;   -- NB: niente costo_materiale / sfrido_pct

drop view if exists public.komunigo_configuratori_voci;
create view public.komunigo_configuratori_voci as
select
  c.id,
  c.prodotto_id,
  c.descrizione,
  c.tipo,
  c.modo,
  c.opzionale,
  c.ordine
from public.prodotti_config_voci c;        -- NB: niente costo

comment on view public.komunigo_configuratori is
  'Configuratori pubblici Komunigo (senza costi). Il prezzo si calcola via Edge Function.';

-- Permessi di sola lettura per il sito pubblico (anon) e per i loggati (B2B futuro)
grant select on public.komunigo_prodotti             to anon, authenticated;
grant select on public.komunigo_configuratori         to anon, authenticated;
grant select on public.komunigo_configuratori_varianti to anon, authenticated;
grant select on public.komunigo_configuratori_voci     to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. ORDINI DEL NEGOZIO
--    RLS attiva e NESSUNA policy per anon: il browser NON scrive ordini
--    direttamente. La creazione (con prezzi validati) e l'automazione
--    (impegno magazzino / commessa / ordine fornitore) passano da una
--    Edge Function con service_role. Cosi' i prezzi non sono falsificabili.
-- ---------------------------------------------------------------------
create table if not exists public.komunigo_ordini (
  id             uuid primary key default gen_random_uuid(),
  numero         text unique,                       -- es. K-2026-0001
  creato_il      timestamptz not null default now(),
  stato          text not null default 'nuovo'
                 check (stato in ('nuovo','pagato','in_lavorazione','spedito','annullato')),
  -- dati cliente (ospite; il collegamento all'anagrafica clienti e' Fase 2 B2B)
  cliente_nome   text,
  cliente_email  text,
  cliente_tel    text,
  spedizione     jsonb default '{}'::jsonb,          -- indirizzo, note consegna
  -- economia dell'ordine
  imponibile     numeric(12,2) default 0,
  iva            numeric(12,2) default 0,
  totale         numeric(12,2) default 0,
  -- pagamento (Nexi): riferimenti restituiti dal gateway, MAI dati carta
  pagamento_provider text default 'nexi',
  pagamento_ref  text,
  pagamento_stato text default 'in_attesa',
  -- collegamenti al gestionale creati dall'automazione
  commessa_id    uuid references public.commesse (id),
  note           text default ''
);

create table if not exists public.komunigo_ordini_righe (
  id             uuid primary key default gen_random_uuid(),
  ordine_id      uuid not null references public.komunigo_ordini (id) on delete cascade,
  tipo           text not null default 'prodotto'
                 check (tipo in ('prodotto','configurabile')),
  articolo_id    uuid references public.articoli (id),
  prodotto_config_id uuid references public.prodotti_config (id),
  descrizione    text not null default '',
  config         jsonb default '{}'::jsonb,          -- variante, misure, opzioni, file caricato
  quantita       numeric(12,2) not null default 1,
  prezzo_unitario numeric(12,2) not null default 0,
  prezzo_totale  numeric(12,2) not null default 0,
  ordine         int default 0
);
create index if not exists ko_righe_ordine_idx on public.komunigo_ordini_righe (ordine_id);

alter table public.komunigo_ordini       enable row level security;
alter table public.komunigo_ordini_righe enable row level security;
-- Nessuna policy per anon/authenticated: default = DENY.
-- Solo service_role (Edge Function) puo' leggere/scrivere. In Fase 2 (area B2B)
-- si aggiungera' una policy "il cliente vede i PROPRI ordini" con auth.uid().

-- Fine migrazione Komunigo v1.
