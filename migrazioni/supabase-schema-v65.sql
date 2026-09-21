-- =====================================================================
--  MIGRAZIONE v65 - "mq per lastra" sui materiali
--
--  Le lastre si CONTANO a lastra intera, ma si CONSUMANO a mq (e il
--  prelievo/QR scarica in mq). Per avere entrambe le cose senza frazioni,
--  la giacenza resta in mq e l'articolo memorizza quanti mq vale UNA lastra
--  intera (es. 305x205 cm = 6,25 mq/lastra). Cosi' l'app puo':
--   - mostrare la giacenza anche in numero di lastre (75 mq = ~12 lastre)
--   - caricare/scaricare inserendo le LASTRE, convertendo in mq da sola.
--
--  Facoltativo: vuoto = materiale non gestito a lastra (es. bobine a metro).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.articoli add column if not exists mq_per_lastra numeric;

-- Espongo mq_per_lastra anche nella vista senza prezzi usata dal modulo Magazzino
-- (cosi' le Giacenze e il carico/scarico possono contare a lastre anche per la produzione).
-- Ricreo la vista com'era in v48, con la colonna in piu' in fondo.
drop view if exists public.articoli_magazzino;
create view public.articoli_magazzino as
select
  a.id, a.codice, a.nome_articolo, a.unita, a.tipo,
  a.giacenza, a.impegnato, a.scorta_minima, a.mq_per_lastra
from public.articoli a
where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione');

grant select on public.articoli_magazzino to authenticated;
comment on view public.articoli_magazzino is
  'Vista articoli senza dati economici: usata dal modulo Magazzino (incl. ruolo magazzino).';

-- Fine migrazione v65.
