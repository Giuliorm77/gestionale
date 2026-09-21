-- =====================================================================
--  MIGRAZIONE v51 - FIX SICUREZZA sui controlli di ruolo (Fase A/B)
--
--  Bug: in `if v_ruolo not in (...)` un ruolo NULL (utente NON autenticato)
--  rendeva l'espressione NULL, e `if NULL` NON solleva l'eccezione -> il
--  controllo veniva scavalcato, permettendo a un anonimo di creare/modificare
--  pezzi. Corretto con `v_ruolo is null or v_ruolo not in (...)`.
--
--  Inoltre: pulisce le righe create senza utente (chiamate non autenticate di
--  test) e fa ripartire la numerazione dei codici da 1.
--
--  Additiva/correttiva. Richiede v49 e v50. Da eseguire in Supabase -> Run.
-- =====================================================================

-- 1) pulizia righe fantasma (create da chiamate non autenticate) + reset numerazione
delete from public.magazzino_pezzi where creato_da is null;
alter sequence public.magazzino_pezzi_seq restart with 1;

-- 2) preleva_per_commessa con controllo ruolo CORRETTO
create or replace function public.preleva_per_commessa(
  p_articolo_id uuid,
  p_commessa_id uuid,
  p_larghezza numeric default null,
  p_altezza numeric default null,
  p_spessore numeric default null,
  p_quantita int default 1,
  p_ubicazione text default '',
  p_note text default ''
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  v_codice text;
  v_num text;
  v_mq numeric;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  v_codice := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
  insert into public.magazzino_pezzi
    (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
     stato, commessa_id, ubicazione, note, creato_da)
  values
    (v_codice, p_articolo_id, p_larghezza, p_altezza, p_spessore, coalesce(p_quantita,1),
     'uscito', p_commessa_id, coalesce(p_ubicazione,''), coalesce(p_note,''), auth.uid());
  v_mq := (coalesce(p_larghezza,0) * coalesce(p_altezza,0) / 10000.0) * coalesce(p_quantita,1);
  if v_mq > 0 and p_articolo_id is not null then
    select numero into v_num from public.commesse where id = p_commessa_id;
    insert into public.movimenti_magazzino (articolo_id, tipo, quantita, causale, riferimento, creato_da)
    values (p_articolo_id, 'scarico', v_mq, 'Prelievo per lavorazione',
            'Commessa ' || coalesce(v_num, p_commessa_id::text), auth.uid());
  end if;
  return v_codice;
end;
$$;

grant execute on function public.preleva_per_commessa(uuid,uuid,numeric,numeric,numeric,int,text,text) to authenticated;

-- 3) registra_rientro con controllo ruolo CORRETTO
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
    return null;
  else
    update public.magazzino_pezzi set stato = 'consumato' where id = v_p.id;
    return null;
  end if;
end;
$$;

grant execute on function public.registra_rientro(uuid,text,numeric,numeric,numeric,int,text,text) to authenticated;

-- Fine migrazione v51 (fix controllo ruolo + pulizia).
