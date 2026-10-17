-- =====================================================================
--  Migrazione v177 — Un solo consuntivo per commessa
--  "Genera consuntivo" crea il preventivo-consuntivo (bozza) E salva lo
--  snapshot nell'archivio Consuntivi; la commessa ricorda quale ha generato
--  e non ne fa generare un secondo (finché quel preventivo esiste).
-- =====================================================================

alter table public.commesse add column if not exists consuntivo_preventivo_id     uuid;
alter table public.commesse add column if not exists consuntivo_preventivo_numero text;

-- recupero dei consuntivi già generati (descrizione "Consuntivo commessa <numero>"): il più recente
update public.commesse c
   set consuntivo_preventivo_id = p.id, consuntivo_preventivo_numero = p.numero
  from (
    select distinct on (descrizione_breve) id, numero, descrizione_breve
      from public.preventivi
     where descrizione_breve like 'Consuntivo commessa %'
     order by descrizione_breve, creato_il desc
  ) p
 where p.descrizione_breve = 'Consuntivo commessa ' || c.numero
   and c.consuntivo_preventivo_id is null;

-- Fine migrazione v177.
