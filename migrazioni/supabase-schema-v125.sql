-- =====================================================================
--  Migrazione v125 — Vista "Materiale in arrivo" per il magazzino
--  Funzione security-definer: espone gli ordini fornitore NON ancora ricevuti
--  (righe con articolo non completamente arrivato) SENZA prezzi, così anche il
--  magazzino (che non ha accesso al modulo Ordini fornitori) può vederli.
--  Additiva e reversibile.
-- =====================================================================

create or replace function public.materiale_in_arrivo()
returns table(
  ordine_id uuid, numero text, fornitore_nome text,
  commessa_id uuid, commessa_numero text, cliente_nome text,
  data_prevista date, stato text,
  riga_descrizione text, articolo_id uuid, quantita numeric, quantita_ricevuta numeric
)
language sql security definer set search_path = public as $$
  select o.id, o.numero, o.fornitore_nome,
         o.commessa_id, c.numero, c.cliente_nome,
         o.data_prevista::date, o.stato,
         r.descrizione, r.articolo_id, r.quantita, r.quantita_ricevuta
  from public.ordini_fornitore o
  join public.ordini_fornitore_righe r on r.ordine_id = o.id
  left join public.commesse c on c.id = o.commessa_id
  where coalesce(o.stato,'') not in ('ricevuto','annullato')
    and r.articolo_id is not null
    and coalesce(r.quantita,0) - coalesce(r.quantita_ricevuta,0) > 0
  order by o.data_prevista nulls last, o.numero;
$$;
grant execute on function public.materiale_in_arrivo() to authenticated;

-- Fine migrazione v125.
-- (Per annullare: drop function if exists public.materiale_in_arrivo();)
