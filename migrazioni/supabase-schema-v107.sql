-- =====================================================================
--  Migrazione v107 — Campi di vendita online per i configuratori
--  Il cliente sul negozio vede solo i campi decisi dallo staff → prezzo.
--  v1: misura LIBERA con min/max + QUANTITÀ a scaglioni.
--  Additiva e reversibile. (Aggiorna anche la vista pubblica Komunigo.)
-- =====================================================================

alter table public.prodotti_config
  add column if not exists shop_mis_min  numeric(10,2) not null default 0,  -- cm per lato, 0 = nessun limite
  add column if not exists shop_mis_max  numeric(10,2) not null default 0,  -- cm per lato, 0 = nessun limite
  add column if not exists shop_quantita jsonb;                             -- es. [100,250,500,1000]; null/[] = quantità libera

-- vista pubblica aggiornata: espone i campi di vendita (NON espone costi)
drop view if exists public.komunigo_configuratori;
create view public.komunigo_configuratori as
select p.id, p.nome, p.unita_calcolo, p.minimo, p.note, p.tipo,
       nullif(p.categoria,'') as categoria, p.giorni_lavorazione,
       p.shop_mis_min, p.shop_mis_max, p.shop_quantita
from public.prodotti_config p
where p.attivo = true;
grant select on public.komunigo_configuratori to anon, authenticated;

-- Fine migrazione v107.
-- (Per annullare: ripristinare la vista senza i 3 campi e droppare le colonne shop_*.)
