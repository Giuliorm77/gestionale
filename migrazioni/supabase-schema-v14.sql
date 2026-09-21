-- =====================================================================
--  MIGRAZIONE v14 - PRODOTTI CONFIGURABILI (motore misure -> prezzo)
--  Definizione riutilizzabile: materiale + lavorazioni + margine + sfrido.
--  Usato dai Preventivi (misure -> prezzo automatico) e in futuro dal
--  configuratore e-commerce.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.prodotti_config (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null,
  unita_calcolo   text not null default 'mq' check (unita_calcolo in ('mq','ml','pz')),
  materiale_id    uuid references public.articoli (id),
  costo_materiale numeric(12,2) default 0,   -- € per unita_calcolo (es. 10 €/mq)
  sfrido_pct      numeric default 0,          -- % scarto sul materiale
  margine_pct     numeric default 0,          -- margine obiettivo sul prezzo
  minimo          numeric(12,2) default 0,    -- importo minimo per riga (facoltativo)
  attivo          boolean not null default true,
  note            text default '',
  creato_il       timestamptz not null default now()
);

create table if not exists public.prodotti_config_voci (
  id           uuid primary key default gen_random_uuid(),
  prodotto_id  uuid not null references public.prodotti_config (id) on delete cascade,
  descrizione  text not null default '',
  tipo         text not null default 'lavorazione' check (tipo in ('lavorazione','opzione')),
  modo         text not null default 'mq' check (modo in ('mq','ml','pz','fisso')),
  costo        numeric(12,2) default 0,
  opzionale    boolean not null default false,
  lavorazione  text default '',
  ordine       int default 0
);
create index if not exists pcv_prod_idx on public.prodotti_config_voci (prodotto_id);

alter table public.prodotti_config      enable row level security;
alter table public.prodotti_config_voci enable row level security;

drop policy if exists prodcfg_all on public.prodotti_config;
create policy prodcfg_all on public.prodotti_config for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists prodcfgv_all on public.prodotti_config_voci;
create policy prodcfgv_all on public.prodotti_config_voci for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v14.
