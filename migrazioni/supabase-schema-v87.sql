-- =====================================================================
--  MIGRAZIONE v87 - Incidenza % su fatturato/acquisti (clienti e fornitori)
--
--  Due funzioni server-side per calcolare, per un anno, il totale per
--  cliente (fatturato = commesse consegnate/chiuse) e per fornitore
--  (acquisti = ordini fornitore non bozza/annullati). Server-side per
--  evitare il tetto dei 1000 record di Supabase e avere totali esatti.
--  Solo per chi ha i permessi economici (dati sensibili).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- Fatturato per cliente (commesse consegnate/chiuse, per anno di data_consegna)
create or replace function public.fatturato_clienti(p_anno int)
returns table(cliente_id uuid, totale numeric)
language sql stable security definer set search_path = public
as $$
  select cliente_id, sum(coalesce(valore,0))::numeric as totale
    from public.commesse
   where public.puo_economici()
     and stato in ('consegnata','chiusa')
     and data_consegna is not null
     and extract(year from data_consegna)::int = p_anno
     and cliente_id is not null
   group by cliente_id;
$$;
grant execute on function public.fatturato_clienti(int) to authenticated;

-- Acquisti per fornitore (ordini fornitore non bozza/annullati, per anno di data)
create or replace function public.acquisti_fornitori(p_anno int)
returns table(fornitore_id uuid, totale numeric)
language sql stable security definer set search_path = public
as $$
  select fornitore_id, sum(coalesce(totale,0))::numeric as totale
    from public.ordini_fornitore
   where public.puo_economici()
     and stato not in ('bozza','annullato')
     and data is not null
     and extract(year from data)::int = p_anno
     and fornitore_id is not null
   group by fornitore_id;
$$;
grant execute on function public.acquisti_fornitori(int) to authenticated;

-- Fine migrazione v87.
