-- =====================================================================
--  MIGRAZIONE v95 - Foto articolo visibili in produzione (Postazione)
--
--  La vista articoli_magazzino (usata da magazzino/produzione, SENZA prezzi)
--  ora espone anche le foto dell'articolo, così l'operatore può vedere cosa
--  deve produrre. Non espone alcun dato economico.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

drop view if exists public.articoli_magazzino;
create view public.articoli_magazzino as
select
  a.id, a.codice, a.nome_articolo, a.unita, a.tipo,
  a.giacenza, a.impegnato, a.scorta_minima, a.mq_per_lastra,
  a.grammatura, a.formato_l, a.formato_h, a.fogli_per_pacco,
  a.foto_urls, a.link_foto
from public.articoli a
where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione');

grant select on public.articoli_magazzino to authenticated;

-- Fine migrazione v95.
