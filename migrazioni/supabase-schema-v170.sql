-- =====================================================================
--  Migrazione v170 — IMPEGNATO = riservato in magazzino NON ancora prelevato
--  Modello WIP confermato:
--    ordinato  = quantità riga di commessa (o il consumo pianificato)
--    prelevato = materiale già scaricato dal magazzino (consumi scaricati)
--    IMPEGNATO = ordinato − prelevato  (ciò che è ancora in magazzino, riservato)
--    disponibile = giacenza − impegnato
--  La giacenza scende al PRELIEVO (Scarica dal magazzino), non al DDT.
--  Le LASTRE (materiale a pezzi) restano escluse.
-- =====================================================================

create or replace function public.ricalcola_impegni()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.articoli set impegnato = 0 where coalesce(impegnato,0) <> 0;

  with righe_agg as (
    select cm.id as commessa_id, r.articolo_id as aid,
           sum(coalesce(r.quantita,0)) as ordinato
      from public.commesse_righe r
      join public.commesse cm on cm.id = r.commessa_id
     where cm.stato in ('aperta','in_produzione','pronta')
       and r.articolo_id is not null
     group by cm.id, r.articolo_id
  ),
  cons_agg as (
    select cm.id as commessa_id, (c->>'articolo_id')::uuid as aid,
           sum(coalesce(nullif(c->>'quantita','')::numeric,0)) as cons_tot,
           sum(case when coalesce((c->>'scaricato')::boolean,false)
                    then coalesce(nullif(c->>'quantita','')::numeric,0) else 0 end) as prelevato
      from public.commesse cm
      cross join lateral jsonb_array_elements(coalesce(cm.consumi,'[]'::jsonb)) c
     where cm.stato in ('aperta','in_produzione','pronta')
       and coalesce(c->>'articolo_id','') <> ''
     group by cm.id, (c->>'articolo_id')::uuid
  ),
  unito as (
    select coalesce(r.commessa_id, c.commessa_id) as commessa_id,
           coalesce(r.aid, c.aid) as aid,
           greatest(coalesce(r.ordinato,0), coalesce(c.cons_tot,0)) as fabbisogno,
           coalesce(c.prelevato,0) as prelevato
      from righe_agg r
      full outer join cons_agg c on c.commessa_id = r.commessa_id and c.aid = r.aid
  ),
  imp as (
    select u.aid, sum(greatest(u.fabbisogno - u.prelevato, 0)) as tot
      from unito u
      join public.articoli ar on ar.id = u.aid
     where coalesce(ar.materiale_tipo,'') <> 'lastra'
     group by u.aid
    having sum(greatest(u.fabbisogno - u.prelevato, 0)) <> 0
  )
  update public.articoli a set impegnato = imp.tot
    from imp where a.id = imp.aid;
end;
$$;

grant execute on function public.ricalcola_impegni() to authenticated;

-- ricalcola subito su tutto
select public.ricalcola_impegni();

-- Fine migrazione v170.
