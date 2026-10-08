-- =====================================================================
--  Migrazione v152 — Provvigioni su INCASSATO (per cliente, su imponibile)
--  - scadenze.importo_netto: imponibile della rata (ricavato dal rapporto
--    netto/lordo della fattura FIC; lo popola fic-sync).
--  - provvigioni_incassato(p_mese): per ogni agente, somma l'incassato netto
--    delle fatture-cliente PAGATE nel mese e la provvigione (% cliente o agente).
-- =====================================================================

alter table public.scadenze add column if not exists importo_netto numeric(12,2);

create or replace function public.provvigioni_incassato(p_mese text default null)
returns table(agente_id uuid, agente_nome text, n_fatture bigint, incassato_netto numeric, provvigione numeric)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.nome, count(*)::bigint,
    coalesce(sum(coalesce(s.importo_netto, s.importo)), 0)::numeric,
    coalesce(sum(coalesce(s.importo_netto, s.importo) * (coalesce(c.provvigione_pct, a.provvigione_pct, 0)/100.0)), 0)::numeric
  from public.scadenze s
  join public.clienti c on c.id = s.cliente_id
  join public.agenti  a on a.id = c.agente_id
  where s.tipo = 'cliente' and s.pagato = true
    and public.ruolo_utente() in ('amministratore','commerciale')
    and (p_mese is null or to_char(s.data_pagamento, 'YYYY-MM') = p_mese)
  group by a.id, a.nome
  order by 5 desc;
$$;

grant execute on function public.provvigioni_incassato(text) to authenticated;

-- Fine migrazione v152.
