-- =====================================================================
--  Migrazione v142 — Valorizzazione magazzino (a COSTO)
--  Somma lato DB il valore delle giacenze, su TUTTO il magazzino
--  (non solo le righe mostrate a video, che sono limitate/filtrate):
--   - sfuso:  Σ giacenza × costo  degli articoli con giacenza > 0
--   - avanzi: Σ costo × quantità   dei pezzi tracciati in magazzino (a scaffale)
--  Dato economico → visibile solo ad amministratore + Back office (commerciale).
--  Additiva e reversibile.
-- =====================================================================

create or replace function public.valorizzazione_magazzino()
returns table(val_sfuso numeric, n_sfuso bigint, val_avanzi numeric, n_avanzi bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- solo ruoli economici (gli altri non devono vedere i valori)
  if public.ruolo_utente() not in ('amministratore','commerciale') then
    raise exception 'non autorizzato';
  end if;
  return query
  select
    coalesce((select sum(greatest(coalesce(a.giacenza,0),0) * coalesce(a.costo,0))
              from public.articoli a where coalesce(a.giacenza,0) > 0), 0)::numeric            as val_sfuso,
    coalesce((select count(*) from public.articoli a where coalesce(a.giacenza,0) > 0), 0)::bigint as n_sfuso,
    coalesce((select sum(coalesce(p.costo,0) * coalesce(p.quantita,1))
              from public.magazzino_pezzi p where p.stato = 'in_magazzino'), 0)::numeric        as val_avanzi,
    coalesce((select count(*) from public.magazzino_pezzi p where p.stato = 'in_magazzino'), 0)::bigint as n_avanzi;
end;
$$;

grant execute on function public.valorizzazione_magazzino() to authenticated;

-- Fine migrazione v142.
-- (Per annullare: drop function if exists public.valorizzazione_magazzino();)
