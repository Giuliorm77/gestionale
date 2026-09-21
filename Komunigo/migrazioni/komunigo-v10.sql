-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v10  (configuratore GADGET)
--
--  COSA FA (tutto ADDITIVO):
--   1) prodotti_config.tipo: 'misura' (i configurabili classici a misura,
--      default) oppure 'gadget' (penne, borracce, magliette… con varianti
--      colore e posizioni di stampa).
--   2) prodotti_config_stampe: le POSIZIONI di stampa di un gadget (es.
--      "Centrato sulla clip"), con area, n° colori max e prezzo.
--   3) viste pubbliche: komunigo_configuratori espone anche 'tipo';
--      komunigo_configuratori_stampe espone le posizioni SENZA prezzi
--      (il prezzo si calcola in Edge Function).
--
--  Per i gadget: unita_calcolo = 'pz', le VARIANTI = colori (costo_materiale =
--  costo per pezzo), minimo = quantità minima ordinabile.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---- 1) tipo prodotto ----
alter table public.prodotti_config
  add column if not exists tipo text not null default 'misura';
do $$ begin
  if not exists (select 1 from pg_constraint where conname='prodotti_config_tipo_chk') then
    alter table public.prodotti_config
      add constraint prodotti_config_tipo_chk check (tipo in ('misura','gadget'));
  end if;
end $$;

-- ---- 2) posizioni di stampa dei gadget ----
create table if not exists public.prodotti_config_stampe (
  id          uuid primary key default gen_random_uuid(),
  prodotto_id uuid not null references public.prodotti_config (id) on delete cascade,
  nome        text not null default '',          -- es. "Centrato sulla clip"
  area_cm     text not null default '',          -- es. "3 × 4,3"
  max_colori  int  not null default 4,           -- quanti colori al massimo
  prezzo_pz   numeric(12,4) not null default 0,  -- costo per pezzo, per colore
  setup       numeric(12,2) not null default 0,  -- costo una-tantum di attrezzaggio
  ordine      int  not null default 0
);
create index if not exists pcs_prodotto_idx on public.prodotti_config_stampe (prodotto_id);

alter table public.prodotti_config_stampe enable row level security;
drop policy if exists prodcfgstampe_all on public.prodotti_config_stampe;
create policy prodcfgstampe_all on public.prodotti_config_stampe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---- 3) viste pubbliche ----
drop view if exists public.komunigo_configuratori;
create view public.komunigo_configuratori as
select p.id, p.nome, p.unita_calcolo, p.minimo, p.note, p.tipo
from public.prodotti_config p
where p.attivo = true;
grant select on public.komunigo_configuratori to anon, authenticated;

drop view if exists public.komunigo_configuratori_stampe;
create view public.komunigo_configuratori_stampe as
select s.id, s.prodotto_id, s.nome, s.area_cm, s.max_colori, s.ordine
from public.prodotti_config_stampe s;   -- NB: niente prezzi
grant select on public.komunigo_configuratori_stampe to anon, authenticated;

-- Fine migrazione Komunigo v10.
