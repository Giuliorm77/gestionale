-- =====================================================================
--  MIGRAZIONE v33 - IMPEGNO STOCK (prenotazione materiali)
--
--  Quando un preventivo diventa commessa, i suoi materiali risultano
--  IMPEGNATI: la giacenza fisica non cambia, ma la DISPONIBILITA' cala.
--    disponibile = giacenza (fisica) - impegnato
--
--  articoli.impegnato viene RICALCOLATO dalla funzione ricalcola_impegni()
--  a partire dalla fonte di verita' (commesse.consumi non ancora scaricati,
--  delle commesse attive). L'app la chiama dopo ogni modifica alle commesse.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.articoli add column if not exists impegnato numeric(12,2) default 0;

create or replace function public.ricalcola_impegni()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- azzera gli impegni attuali
  update public.articoli set impegnato = 0 where coalesce(impegnato,0) <> 0;
  -- ricalcola dagli articoli non ancora scaricati delle commesse ATTIVE
  update public.articoli a
     set impegnato = sub.tot
    from (
      select (c->>'articolo_id')::uuid as aid,
             sum(coalesce(nullif(c->>'quantita','')::numeric,0)) as tot
        from public.commesse cm
        cross join lateral jsonb_array_elements(coalesce(cm.consumi,'[]'::jsonb)) c
       where cm.stato in ('aperta','in_produzione','pronta')
         and coalesce((c->>'scaricato')::boolean, false) = false
         and coalesce(c->>'articolo_id','') <> ''
       group by (c->>'articolo_id')::uuid
    ) sub
   where a.id = sub.aid;
end;
$$;

grant execute on function public.ricalcola_impegni() to authenticated;

-- inizializza subito
select public.ricalcola_impegni();

-- Fine migrazione v33.
