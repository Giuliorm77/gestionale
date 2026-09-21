-- =====================================================================
--  MIGRAZIONE v84 - MAGAZZINO: dettaglio "impegnato" per commessa
--
--  Oggi articoli.impegnato e' un numero (somma dei consumi non ancora
--  scaricati delle commesse attive - vedi v33 ricalcola_impegni()).
--  Il magazzino vuole vedere, per un articolo impegnato, A CHI e' assegnato:
--  quali commesse lo hanno prenotato e quanta quantita' ciascuna.
--
--  Esponiamo una funzione security-definer che ritorna SOLO dati NON
--  economici (numero commessa, cliente, stato, quantita'), cosi' e'
--  usabile anche dal ruolo 'magazzino' senza aprire i costi delle commesse.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create or replace function public.impegni_dettaglio()
returns table(
  articolo_id  uuid,
  commessa_id  uuid,
  numero       text,
  cliente_nome text,
  stato        text,
  quantita     numeric
)
language sql stable security definer set search_path = public
as $$
  select (c->>'articolo_id')::uuid            as articolo_id,
         cm.id                                 as commessa_id,
         cm.numero                             as numero,
         cm.cliente_nome                       as cliente_nome,
         cm.stato                              as stato,
         sum(coalesce(nullif(c->>'quantita','')::numeric,0)) as quantita
    from public.commesse cm
    cross join lateral jsonb_array_elements(coalesce(cm.consumi,'[]'::jsonb)) c
   where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione')
     and cm.stato in ('aperta','in_produzione','pronta')
     and coalesce((c->>'scaricato')::boolean, false) = false
     and coalesce(c->>'articolo_id','') <> ''
   group by (c->>'articolo_id')::uuid, cm.id, cm.numero, cm.cliente_nome, cm.stato
  having sum(coalesce(nullif(c->>'quantita','')::numeric,0)) <> 0;
$$;

grant execute on function public.impegni_dettaglio() to authenticated;

-- Fine migrazione v84.
