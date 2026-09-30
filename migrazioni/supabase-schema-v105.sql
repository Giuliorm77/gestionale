-- =====================================================================
--  Migrazione v105 — "Chiedi chi paga il materiale" solo per lastre/carta
--  Flag sull'articolo: traccia_avanzo. Nel preventivo la scelta
--  "Paga tutta la lastra / Paga solo l'usato" compare SOLO per i materiali
--  con questo flag (lastre, pacchi di carta). Tutto il resto (gadget, penne) no.
--  Additiva e reversibile.
-- =====================================================================

alter table public.articoli
  add column if not exists traccia_avanzo boolean not null default false;

-- Pre-attiva il flag sui materiali venduti a superficie/lunghezza (lastre, vinile):
-- così non vanno taggati a mano. La carta (se a pezzi/risme) va spuntata a mano.
update public.articoli
   set traccia_avanzo = true
 where traccia_avanzo = false
   and lower(coalesce(unita,'')) in ('mq','m²','mq.','mq2','ml','mtl','m','ml.');

-- Fine migrazione v105.
-- (Per annullare: alter table public.articoli drop column traccia_avanzo;)
