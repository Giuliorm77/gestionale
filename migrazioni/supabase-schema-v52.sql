-- =====================================================================
--  MIGRAZIONE v52 - AVANZI: valorizzazione (FASE C, parte 1)
--
--  L'avanzo che rientra nasce valorizzato a COSTO ZERO: la lastra d'origine è
--  già stata pagata dalla commessa, quindi il ritaglio recuperato è "materiale
--  gratis in casa" -> leva per il commerciale sui lavori futuri. Il commerciale
--  può poi rivalorizzarlo (costo d'acquisto o manuale) dal modulo Pezzi.
--
--  Aggiorna registra_rientro: il pezzo avanzo viene creato con
--  valorizzazione='zero' e costo=0. (Controllo ruolo già corretto in v51.)
--
--  Additiva/correttiva. Richiede v49/v50/v51. Da eseguire in Supabase -> Run.
-- =====================================================================

create or replace function public.registra_rientro(
  p_pezzo_id  uuid,
  p_esito     text,
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
    update public.magazzino_pezzi set stato = 'consumato' where id = v_p.id;
    v_codice := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
    insert into public.magazzino_pezzi
      (codice, articolo_id, pezzo_padre_id, larghezza_cm, altezza_cm, spessore_mm,
       quantita, stato, costo, valorizzazione, ubicazione, note, creato_da)
    values
      (v_codice, v_p.articolo_id, v_p.id, p_larghezza, p_altezza, p_spessore,
       coalesce(p_quantita,1), 'in_magazzino', 0, 'zero', coalesce(p_ubicazione,''), coalesce(p_note,''), auth.uid());
    return v_codice;
  elsif p_esito = 'perso' then
    update public.magazzino_pezzi
       set stato = 'perso',
           note  = btrim(coalesce(note,'') || ' | perso: ' || coalesce(p_note,''))
     where id = v_p.id;
    return null;
  else
    update public.magazzino_pezzi set stato = 'consumato' where id = v_p.id;
    return null;
  end if;
end;
$$;

grant execute on function public.registra_rientro(uuid,text,numeric,numeric,numeric,int,text,text) to authenticated;

-- Fine migrazione v52 (avanzo a costo zero di default).
