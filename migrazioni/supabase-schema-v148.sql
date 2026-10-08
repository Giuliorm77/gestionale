-- =====================================================================
--  Migrazione v148 — Filtro per ANNO nei totali Scadenzario
--  scadenze_totali ora accetta un anno (anno del documento/fattura).
--  p_anno null = tutti gli anni.
-- =====================================================================

drop function if exists public.scadenze_totali();

create or replace function public.scadenze_totali(p_anno int default null)
returns table(tipo text, totale_aperto numeric, totale_scaduto numeric, n_aperte bigint)
language sql
stable
security definer
set search_path = public
as $$
  select s.tipo,
    coalesce(sum(s.importo) filter (where not s.pagato), 0)::numeric,
    coalesce(sum(s.importo) filter (where not s.pagato and s.data_scadenza is not null and s.data_scadenza < current_date), 0)::numeric,
    count(*) filter (where not s.pagato)::bigint
  from public.scadenze s
  where public.ruolo_utente() in ('amministratore','commerciale')
    and (p_anno is null or extract(year from s.data_documento) = p_anno)
  group by s.tipo;
$$;

grant execute on function public.scadenze_totali(int) to authenticated;

-- Fine migrazione v148.
