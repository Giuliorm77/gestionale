-- =====================================================================
--  MIGRAZIONE v77 - CARTA: formato, grammatura, conversioni a foglio
--
--  La carta si USA/PREVENTIVA a FOGLIO, ma si COMPRA a kg / pacco / foglio.
--  Con grammatura (g/m2) e formato (L x H, cm) si ricava:
--    peso/foglio (kg) = grammatura * (L/100 * H/100) / 1000
--    fogli/kg        = 1 / peso_foglio
--    costo/foglio    = prezzo_al_kg * peso_foglio
--  Un "pacco" (risma) contiene un numero fisso di fogli.
--
--  Questi campi servono all'articolo (unita = foglio) per calcolare il costo
--  e per convertire i carichi di magazzino (bolla in kg/pacco -> fogli).
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.articoli add column if not exists grammatura     numeric default 0;   -- g/m2
alter table public.articoli add column if not exists formato_l       numeric default 0;   -- cm
alter table public.articoli add column if not exists formato_h       numeric default 0;   -- cm
alter table public.articoli add column if not exists fogli_per_pacco numeric default 0;   -- fogli in un pacco/risma

-- Ricreo la vista senza prezzi (usata dal Magazzino, incl. ruolo magazzino) con i nuovi campi,
-- così il carico bolla puo' convertire kg/pacco -> fogli anche per chi non e' economico.
drop view if exists public.articoli_magazzino;
create view public.articoli_magazzino as
select
  a.id, a.codice, a.nome_articolo, a.unita, a.tipo,
  a.giacenza, a.impegnato, a.scorta_minima, a.mq_per_lastra,
  a.grammatura, a.formato_l, a.formato_h, a.fogli_per_pacco
from public.articoli a
where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione');

grant select on public.articoli_magazzino to authenticated;

-- Fine migrazione v77.
