-- =====================================================================
--  MIGRAZIONE v50 - AVANZI/LASTRE: RIENTRO dopo lavorazione (FASE B)
--
--  "Come esce deve rientrare": il pezzo uscito su una commessa (stato 'uscito')
--  viene riconciliato al rientro. Tre esiti:
--   - 'avanzo'    -> è tornato un ritaglio riutilizzabile: si chiude l'originale
--                    ('consumato') e nasce un PEZZO FIGLIO avanzo ('in_magazzino')
--                    con le sue misure e un NUOVO codice (nuova etichetta).
--   - 'consumato' -> tutto usato, nessun avanzo.
--   - 'perso'     -> non rientra per errore interno: stato 'perso'. Il costo a
--                    carico della commessa (che intacca il margine) = Fase C.
--
--  Additiva: aggiunge solo la funzione. Da eseguire in Supabase -> SQL Editor -> Run.
--  Richiede v49 (tabella magazzino_pezzi, sequenza, ruoli).
-- =====================================================================

create or replace function public.registra_rientro(
  p_pezzo_id  uuid,
  p_esito     text,                    -- 'avanzo' | 'consumato' | 'perso'
  p_larghezza numeric default null,
  p_altezza   numeric default null,
  p_spessore  numeric default null,
  p_quantita  int     default 1,
  p_ubicazione text   default '',
  p_note      text    default ''
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruolo  text := public.ruolo_utente();
  v_p      public.magazzino_pezzi;
  v_codice text;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;

  select * into v_p from public.magazzino_pezzi where id = p_pezzo_id;
  if not found then raise exception 'Pezzo non trovato'; end if;
  if v_p.stato <> 'uscito' then
    raise exception 'Il pezzo non è in lavorazione (stato attuale: %)', v_p.stato;
  end if;

  if p_esito = 'avanzo' then
    -- chiude l'originale e crea il pezzo AVANZO (figlio), riutilizzabile a scaffale
    update public.magazzino_pezzi set stato = 'consumato' where id = v_p.id;
    v_codice := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
    insert into public.magazzino_pezzi
      (codice, articolo_id, pezzo_padre_id, larghezza_cm, altezza_cm, spessore_mm,
       quantita, stato, ubicazione, note, creato_da)
    values
      (v_codice, v_p.articolo_id, v_p.id, p_larghezza, p_altezza, p_spessore,
       coalesce(p_quantita,1), 'in_magazzino', coalesce(p_ubicazione,''), coalesce(p_note,''), auth.uid());
    return v_codice;

  elsif p_esito = 'perso' then
    update public.magazzino_pezzi
       set stato = 'perso',
           note  = btrim(coalesce(note,'') || ' | perso: ' || coalesce(p_note,''))
     where id = v_p.id;
    return null;                       -- il costo sulla commessa = Fase C

  else  -- 'consumato'
    update public.magazzino_pezzi set stato = 'consumato' where id = v_p.id;
    return null;
  end if;
end;
$$;

grant execute on function public.registra_rientro(uuid,text,numeric,numeric,numeric,int,text,text) to authenticated;

-- Fine migrazione v50 (Fase B: rientro avanzo / consumato / perso).
