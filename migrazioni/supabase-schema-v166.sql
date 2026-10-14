-- =====================================================================
--  Migrazione v166 — articoli_magazzino espone materiale_tipo (+ formati)
--  Serve al "Carico pannelli" e alla gestione lastre a pezzi (Fase 1/2):
--  i form leggono materiale_tipo dalla vista articoli_magazzino, che finora
--  non lo esponeva (la select andava in errore -> lista articoli vuota).
--  Additiva/ricreazione vista. Nessun dato economico esposto.
-- =====================================================================

drop view if exists public.articoli_magazzino;
create view public.articoli_magazzino as
select
  a.id, a.codice, a.nome_articolo, a.unita, a.tipo,
  a.giacenza, a.impegnato, a.scorta_minima, a.mq_per_lastra,
  a.grammatura, a.formato_l, a.formato_h, a.fogli_per_pacco,
  a.foto_urls, a.link_foto,
  a.materiale_tipo, a.formati
from public.articoli a
where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione');

grant select on public.articoli_magazzino to authenticated;

-- Fine migrazione v166.
