-- =====================================================================
--  MIGRAZIONE v79 - ORE REALI IN PRODUZIONE per operatore
--
--  Per gli operatori "misto" (produzione + ufficio) non serve stimare a mano
--  le ore in produzione: le ricaviamo dai segmenti di lavoro veri (Postazione).
--  Questa funzione somma le ore cronometrate di un operatore da una certa data.
--  Calcolo LATO SERVER: niente limite di 1000 righe, il totale e' sempre giusto.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create or replace function public.ore_produzione_operatore(p_operatore_id uuid, p_dal timestamptz)
returns numeric
language sql
security definer
set search_path = public
as $$
  select coalesce(sum(extract(epoch from (fine - inizio)) / 3600.0), 0)
    from public.segmenti_lavoro
   where operatore_id = p_operatore_id
     and fine is not null
     and inizio >= p_dal;
$$;

grant execute on function public.ore_produzione_operatore(uuid, timestamptz) to authenticated;

-- Fine migrazione v79.
