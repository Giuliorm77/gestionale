-- =====================================================================
--  MIGRAZIONE v15 - Prodotti configurabili: VARIANTI + FASCE QUANTITA' + unita mc/mtl
--  (modello alla Pixartprinting: materiale+spessore come varianti selezionabili,
--   prezzo unitario a scaglioni di quantita)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- Estendo le unita ammesse (mq, mtl, mc, pz) - lascio 'ml' per compatibilita'
alter table public.prodotti_config drop constraint if exists prodotti_config_unita_calcolo_check;
alter table public.prodotti_config add  constraint prodotti_config_unita_calcolo_check
  check (unita_calcolo in ('mq','mtl','ml','mc','pz'));

alter table public.prodotti_config_voci drop constraint if exists prodotti_config_voci_modo_check;
alter table public.prodotti_config_voci add  constraint prodotti_config_voci_modo_check
  check (modo in ('mq','mtl','ml','mc','pz','fisso'));

-- VARIANTI: materiale + spessore selezionabili dentro un prodotto
create table if not exists public.prodotti_config_varianti (
  id              uuid primary key default gen_random_uuid(),
  prodotto_id     uuid not null references public.prodotti_config (id) on delete cascade,
  nome            text not null default '',      -- es. "Forex 3mm"
  spessore        numeric default 0,             -- mm (per volume o riferimento)
  costo_materiale numeric(12,2) default 0,       -- € per unita_calcolo
  sfrido_pct      numeric default 0,
  articolo_id     uuid references public.articoli (id),
  ordine          int default 0
);
create index if not exists pcvar_prod_idx on public.prodotti_config_varianti (prodotto_id);

-- FASCE DI QUANTITA': sconto per scaglione
create table if not exists public.prodotti_config_fasce (
  id           uuid primary key default gen_random_uuid(),
  prodotto_id  uuid not null references public.prodotti_config (id) on delete cascade,
  da_quantita  int default 1,          -- da questa quantita in su
  sconto_pct   numeric default 0,      -- sconto % applicato al prezzo unitario
  ordine       int default 0
);
create index if not exists pcfasce_prod_idx on public.prodotti_config_fasce (prodotto_id);

alter table public.prodotti_config_varianti enable row level security;
alter table public.prodotti_config_fasce    enable row level security;

drop policy if exists pcvar_all on public.prodotti_config_varianti;
create policy pcvar_all on public.prodotti_config_varianti for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists pcfasce_all on public.prodotti_config_fasce;
create policy pcfasce_all on public.prodotti_config_fasce for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v15.
