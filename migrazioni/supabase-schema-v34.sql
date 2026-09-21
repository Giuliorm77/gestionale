-- =====================================================================
--  MIGRAZIONE v34 - Imballo per articolo nella commessa
--
--  In commessa, per ogni articolo si sceglie una RICETTA di imballo
--  (dal modulo 🎁 Imballi, livello "prodotto") e l'app ne calcola il costo
--  dalle misure/quantità. Salviamo la scelta e il costo sulla riga.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_righe add column if not exists imballo_id    uuid references public.imballi (id);
alter table public.commesse_righe add column if not exists imballo_costo numeric(12,2) default 0;

-- Fine migrazione v34.
