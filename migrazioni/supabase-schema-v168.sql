-- =====================================================================
--  Migrazione v168 — Prelievo di PIÙ lastre in una volta (lavori grandi)
--  Quando la misura richiesta non entra in un solo pannello, si impegnano
--  più lastre intere (es. 2). preleva_pezzo_commessa accetta una quantità:
--  scala N dal mucchio e crea il pezzo 'uscito' (quantità N) agganciato alla
--  commessa. Se N = tutto il mucchio, la voce stessa passa a 'uscito'.
-- =====================================================================

drop function if exists public.preleva_pezzo_commessa(uuid,uuid,boolean,text);

create or replace function public.preleva_pezzo_commessa(
  p_pezzo_id      uuid,
  p_commessa_id   uuid,
  p_pagato_intero boolean default null,
  p_note          text    default null,
  p_quantita      int     default 1
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  r       public.magazzino_pezzi%rowtype;
  v_new   text;
  v_n     int;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  select * into r from public.magazzino_pezzi where id = p_pezzo_id;
  if not found then raise exception 'Pannello non trovato'; end if;
  if r.stato <> 'in_magazzino' then
    raise exception 'Il pannello non è disponibile (stato: %)', r.stato;
  end if;
  v_n := greatest(coalesce(p_quantita,1),1);
  if v_n > coalesce(r.quantita,1) then
    raise exception 'Disponibili solo % lastre di questo formato', coalesce(r.quantita,1);
  end if;
  if v_n < coalesce(r.quantita,1) then
    update public.magazzino_pezzi set quantita = quantita - v_n where id = r.id;
    v_new := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
    insert into public.magazzino_pezzi
      (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
       costo, valorizzazione, stato, commessa_id, ubicazione, pagato_intero, note, creato_da)
    values
      (v_new, r.articolo_id, r.larghezza_cm, r.altezza_cm, r.spessore_mm, v_n,
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
grant execute on function public.preleva_pezzo_commessa(uuid,uuid,boolean,text,int) to authenticated;

-- Fine migrazione v168.
