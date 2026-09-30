-- =====================================================================
--  Migrazione v106 — Configuratore "Stampa su carta" (nesting a fogli)
--  Nuovo tipo prodotto 'stampa': calcola pose per foglio, fogli macchina
--  (piccolo formato) e fogli d'acquisto, costo carta + stampa.
--  Additiva e reversibile.
-- =====================================================================

-- 1) tipo 'stampa' ammesso su prodotti_config (drop del check esistente, qualunque nome abbia)
do $$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.prodotti_config'::regclass and contype='c'
     and pg_get_constraintdef(oid) ilike '%tipo%';
  if c is not null then execute 'alter table public.prodotti_config drop constraint '||quote_ident(c); end if;
end $$;
alter table public.prodotti_config
  add constraint prodotti_config_tipo_check check (tipo in ('misura','gadget','stampa'));

-- 2) parametri di stampa sul prodotto
alter table public.prodotti_config
  add column if not exists stampa_vivo_mm       numeric(8,2) not null default 4,
  add column if not exists stampa_margine_mm    numeric(8,2) not null default 8,
  add column if not exists stampa_prezzo_bn     numeric(12,4) not null default 0,
  add column if not exists stampa_prezzo_colore numeric(12,4) not null default 0,
  add column if not exists stampa_avviamento    numeric(12,2) not null default 0,
  add column if not exists stampa_prezzo_mq     numeric(12,4) not null default 0;

-- 3) formato del foglio d'acquisto sulla variante (carta)
alter table public.prodotti_config_varianti
  add column if not exists foglio_l_cm numeric(8,2) not null default 0,
  add column if not exists foglio_h_cm numeric(8,2) not null default 0;

-- Fine migrazione v106.
-- (Per annullare: rimuovere le colonne aggiunte e ripristinare il check a ('misura','gadget').)
