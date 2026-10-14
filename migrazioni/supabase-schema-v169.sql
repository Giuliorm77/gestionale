-- =====================================================================
--  Migrazione v169 — IMPEGNATO anche dalle righe da consegnare
--  Finora "impegnato" = consumi non scaricati. Ora aggiunge anche la quota
--  dei PRODOTTI da consegnare: per ogni riga di commessa attiva con un articolo
--  di magazzino, (quantità − quantità già consegnata) = impegnato.
--  Così la merce ancora da consegnare NON risulta disponibile per altri lavori.
--  Le LASTRE (materiale a pezzi) sono escluse: la loro giacenza è nei pezzi.
--  disponibile = giacenza − impegnato.
-- =====================================================================

create or replace function public.ricalcola_impegni()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.articoli set impegnato = 0 where coalesce(impegnato,0) <> 0;
  update public.articoli a
     set impegnato = sub.tot
    from (
      select aid, sum(q) as tot from (
        -- 1) consumi non ancora scaricati (materiali di produzione prenotati)
        select (c->>'articolo_id')::uuid as aid,
               coalesce(nullif(c->>'quantita','')::numeric,0) as q
          from public.commesse cm
          cross join lateral jsonb_array_elements(coalesce(cm.consumi,'[]'::jsonb)) c
         where cm.stato in ('aperta','in_produzione','pronta')
           and coalesce((c->>'scaricato')::boolean, false) = false
           and coalesce(c->>'articolo_id','') <> ''
        union all
        -- 2) prodotti da consegnare: (quantità riga − già consegnata), solo NON-lastra
        select r.articolo_id as aid,
               greatest(coalesce(r.quantita,0) - coalesce(r.quantita_consegnata,0), 0) as q
          from public.commesse_righe r
          join public.commesse cm on cm.id = r.commessa_id
          left join public.articoli ar on ar.id = r.articolo_id
         where cm.stato in ('aperta','in_produzione','pronta')
           and r.articolo_id is not null
           and coalesce(ar.materiale_tipo,'') <> 'lastra'
      ) z
      where aid is not null
      group by aid
      having sum(q) <> 0
    ) sub
   where a.id = sub.aid;
end;
$$;

grant execute on function public.ricalcola_impegni() to authenticated;

-- ricalcola subito su tutto (aggiorna anche le commesse già esistenti)
select public.ricalcola_impegni();

-- Fine migrazione v169.
