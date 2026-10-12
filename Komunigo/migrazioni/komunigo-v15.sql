-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v15  (tecnica di stampa per posizione)
--
--  Aggiunge prodotti_config_stampe.tecnica (es. Serigrafia, Tampografia,
--  Stampa digitale, Ricamo, Incisione laser...) e la espone nella vista
--  pubblica komunigo_configuratori_stampe (senza prezzi, come prima).
--  Serve solo a mostrare al cliente la tecnica di ogni posizione: NON entra
--  nel calcolo del prezzo (che resta su prezzo_pz/colori/setup).
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.prodotti_config_stampe
  add column if not exists tecnica text not null default '';

drop view if exists public.komunigo_configuratori_stampe;
create view public.komunigo_configuratori_stampe as
select s.id, s.prodotto_id, s.nome, s.area_cm, s.max_colori, s.tecnica, s.ordine
from public.prodotti_config_stampe s;   -- NB: niente prezzi
grant select on public.komunigo_configuratori_stampe to anon, authenticated;

-- Fine migrazione Komunigo v15.
