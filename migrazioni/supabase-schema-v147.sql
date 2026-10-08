-- =====================================================================
--  Migrazione v147 — Totali Scadenzario lato DB (evita il limite 1000 righe)
--  Il modulo caricava max 1000 scadenze e sommava solo quelle (totali errati).
--  Questa RPC somma lato database, su TUTTE le scadenze, per tipo.
--  Economici only.
-- =====================================================================

create or replace function public.scadenze_totali()
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
  group by s.tipo;
$$;

grant execute on function public.scadenze_totali() to authenticated;

-- Fine migrazione v147.
