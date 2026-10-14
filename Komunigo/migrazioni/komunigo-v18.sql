-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v18  (ordini ai fornitori dagli ordini Komunigo)
--
--  Un ordine Komunigo può contenere prodotti di PIÙ fornitori (capi da cataloghi
--  diversi, gadget di fornitori diversi). Il server (edge komunigo-ordine,
--  azione "ordini-fornitore") divide le righe per fornitore e crea UN ordine
--  fornitore (bozza) per ciascuno. Le righe senza fornitore = produzione interna.
--
--  - catalogo_fornitore_sync.fornitore_id : a quale fornitore in ANAGRAFICA
--    corrisponde ogni catalogo importato (es. 'newwave' → New Wave Italia)
--  - prodotti_config.fornitore_id / fornitore_codice : "fornitore del neutro"
--    dei gadget (penne, borracce…) + suo codice articolo
--  - ordini_fornitore.komunigo_ordine_id : collega l'ordine fornitore
--    all'ordine Komunigo da cui nasce (niente doppioni)
--  - komunigo_ordini.ordini_fornitore_il : quando sono stati generati
--
--  Quando parte: carta di credito → automatico alla conferma del pagamento
--  (webhook Nexi, da fare); bonifico / ritiro / conto aperto → pulsante manuale.
--  Additiva. Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.catalogo_fornitore_sync
  add column if not exists fornitore_id uuid references public.fornitori (id) on delete set null;

alter table public.prodotti_config
  add column if not exists fornitore_id     uuid references public.fornitori (id) on delete set null,
  add column if not exists fornitore_codice text not null default '';

alter table public.ordini_fornitore
  add column if not exists komunigo_ordine_id uuid references public.komunigo_ordini (id) on delete set null;
create index if not exists of_komunigo_idx on public.ordini_fornitore (komunigo_ordine_id);

alter table public.komunigo_ordini
  add column if not exists ordini_fornitore_il timestamptz;

-- collega in automatico il catalogo New Wave al fornitore in anagrafica (se c'è)
update public.catalogo_fornitore_sync s
set fornitore_id = f.id
from (select id from public.fornitori where ragione_sociale ilike '%new wave%' order by ragione_sociale limit 1) f
where s.fornitore = 'newwave' and s.fornitore_id is null;

-- controllo
select s.fornitore, s.nome, s.fornitore_id, f.ragione_sociale as in_anagrafica
from public.catalogo_fornitore_sync s left join public.fornitori f on f.id = s.fornitore_id;

-- Fine migrazione Komunigo v18.
