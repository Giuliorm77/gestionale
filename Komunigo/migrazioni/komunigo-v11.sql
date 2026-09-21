-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v11  (Fase C: categorie + tempi di consegna)
--
--  COSA FA (tutto ADDITIVO):
--   1) prodotti_config.categoria: categoria merceologica per il filtro del
--      catalogo (es. "Stampa", "Insegne", "Gadget"…). Gli articoli ce l'hanno già.
--   2) giorni_lavorazione: giorni lavorativi di produzione, per stimare la data
--      di spedizione (su prodotti_config e articoli; 0 = pronto/veloce).
--   3) viste pubbliche aggiornate: komunigo_configuratori e komunigo_prodotti
--      espongono categoria e giorni_lavorazione.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.prodotti_config
  add column if not exists categoria text not null default '',
  add column if not exists giorni_lavorazione int not null default 0;

alter table public.articoli
  add column if not exists giorni_lavorazione int not null default 0;

-- ---- viste pubbliche ----
drop view if exists public.komunigo_configuratori;
create view public.komunigo_configuratori as
select p.id, p.nome, p.unita_calcolo, p.minimo, p.note, p.tipo,
       nullif(p.categoria,'') as categoria, p.giorni_lavorazione
from public.prodotti_config p
where p.attivo = true;
grant select on public.komunigo_configuratori to anon, authenticated;

drop view if exists public.komunigo_prodotti;
create view public.komunigo_prodotti as
select
  a.id, a.codice, a.nome_articolo as nome, a.descrizione_articolo as descrizione,
  a.categoria, a.unita, a.prezzo_pubblico as prezzo,
  greatest(coalesce(a.giacenza,0) - coalesce(a.impegnato,0), 0) as disponibile,
  a.foto_urls, a.giorni_lavorazione
from public.articoli a
where a.vendibile = true;
grant select on public.komunigo_prodotti to anon, authenticated;

-- Fine migrazione Komunigo v11.
