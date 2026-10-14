-- =====================================================================
--  Migrazione v167 — Lastre intere a QUANTITÀ (non 1 etichetta per lastra)
--  Le lastre nuove identiche si caricano come una voce con QUANTITÀ (es. 100),
--  senza etichettarle una per una. L'etichetta/QR nasce al PRELIEVO (la lastra
--  che esce verso la commessa) e al RIENTRO (l'avanzo). Rivede:
--   - carica_pannelli: UNA riga con quantita = N
--   - preleva_pezzo_commessa: scala 1 dal mucchio e crea il pezzo 'uscito' etichettato
--   - giacenza_pezzi: n = somma delle quantità (numero lastre), non il n° di righe
-- =====================================================================

-- 1) CARICO: una sola voce con quantità N -----------------------------------
create or replace function public.carica_pannelli(
  p_articolo_id    uuid,
  p_larghezza      numeric,
  p_altezza        numeric,
  p_spessore       numeric default null,
  p_quantita       int     default 1,
  p_costo_unitario numeric default null,
  p_ubicazione     text    default '',
  p_note           text    default ''
) returns text[]
language plpgsql security definer set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  v_cod   text;
  v_val   text;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale') then
    raise exception 'Non autorizzato';
  end if;
  if p_articolo_id is null then raise exception 'Articolo mancante'; end if;
  v_val := case when p_costo_unitario is null then 'manuale'
                when p_costo_unitario = 0   then 'zero'
                else 'acquisto' end;
  v_cod := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
  insert into public.magazzino_pezzi
    (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
     costo, valorizzazione, stato, ubicazione, note, creato_da)
  values
    (v_cod, p_articolo_id, p_larghezza, p_altezza, p_spessore, greatest(coalesce(p_quantita,1),1),
     p_costo_unitario, v_val, 'in_magazzino', coalesce(p_ubicazione,''), coalesce(p_note,''), auth.uid());
  return array[v_cod];
end;
$$;
grant execute on function public.carica_pannelli(uuid,numeric,numeric,numeric,int,numeric,text,text) to authenticated;

-- 2) PRELIEVO: scala 1 dal mucchio e crea il pezzo 'uscito' etichettato ------
create or replace function public.preleva_pezzo_commessa(
  p_pezzo_id      uuid,
  p_commessa_id   uuid,
  p_pagato_intero boolean default null,
  p_note          text    default null
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  r       public.magazzino_pezzi%rowtype;
  v_new   text;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  select * into r from public.magazzino_pezzi where id = p_pezzo_id;
  if not found then raise exception 'Pannello non trovato'; end if;
  if r.stato <> 'in_magazzino' then
    raise exception 'Il pannello non è disponibile (stato: %)', r.stato;
  end if;
  if coalesce(r.quantita,1) > 1 then
    -- mucchio di lastre: ne esce 1, il resto resta a scaffale
    update public.magazzino_pezzi set quantita = quantita - 1 where id = r.id;
    v_new := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
    insert into public.magazzino_pezzi
      (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
       costo, valorizzazione, stato, commessa_id, ubicazione, pagato_intero, note, creato_da)
    values
      (v_new, r.articolo_id, r.larghezza_cm, r.altezza_cm, r.spessore_mm, 1,
       r.costo, r.valorizzazione, 'uscito', p_commessa_id, r.ubicazione,
       coalesce(p_pagato_intero, r.pagato_intero), coalesce(nullif(p_note,''), r.note), auth.uid());
    return v_new;
  else
    update public.magazzino_pezzi
       set stato = 'uscito', commessa_id = p_commessa_id,
           pagato_intero = coalesce(p_pagato_intero, pagato_intero),
           note = coalesce(nullif(p_note,''), note)
     where id = r.id;
    return r.codice;
  end if;
end;
$$;
grant execute on function public.preleva_pezzo_commessa(uuid,uuid,boolean,text) to authenticated;

-- 3) GIACENZA a pezzi: n = somma delle quantità (numero lastre) --------------
create or replace function public.giacenza_pezzi(p_ids uuid[])
returns table(articolo_id uuid, n_pezzi bigint, mq numeric)
language sql stable security definer set search_path = public
as $$
  select p.articolo_id,
         coalesce(sum(coalesce(p.quantita,1)),0)::bigint,
         coalesce(sum((coalesce(p.larghezza_cm,0)*coalesce(p.altezza_cm,0)/10000.0)*coalesce(p.quantita,1)),0)::numeric
    from public.magazzino_pezzi p
   where p.stato = 'in_magazzino'
     and p.articolo_id = any(p_ids)
     and public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione')
   group by p.articolo_id;
$$;
grant execute on function public.giacenza_pezzi(uuid[]) to authenticated;

-- Fine migrazione v167.
