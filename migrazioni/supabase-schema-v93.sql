-- =====================================================================
--  MIGRAZIONE v93 - Avanzi: tracciamento "già pagato" (Fase B)
--
--  La decisione "il cliente paga l'intera lastra (avanzo €0) o solo la parte
--  usata (avanzo a costo d'acquisto)" la prende il COMMERCIALE nel preventivo
--  e viaggia fino al rientro. Il flag `pagato_intero` viene stampato sul pezzo
--  al prelievo; al rientro l'avanzo si valorizza DA SOLO in base ad esso.
--
--  Richiede v49/v50/v51/v52. Da eseguire in Supabase -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.magazzino_pezzi add column if not exists pagato_intero boolean not null default true;
-- scelta del commerciale per riga di preventivo (viaggia nei consumi della commessa)
alter table public.preventivi_righe add column if not exists pagato_intero boolean default true;

-- --- preleva_per_commessa: ora riceve e memorizza pagato_intero -------------
drop function if exists public.preleva_per_commessa(uuid,uuid,numeric,numeric,numeric,int,text,text);
create or replace function public.preleva_per_commessa(
  p_articolo_id uuid,
  p_commessa_id uuid,
  p_larghezza numeric default null,
  p_altezza numeric default null,
  p_spessore numeric default null,
  p_quantita int default 1,
  p_ubicazione text default '',
  p_note text default '',
  p_pagato_intero boolean default true
) returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  v_codice text; v_num text; v_mq numeric;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  v_codice := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
  insert into public.magazzino_pezzi
    (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
     stato, commessa_id, ubicazione, note, pagato_intero, creato_da)
  values
    (v_codice, p_articolo_id, p_larghezza, p_altezza, p_spessore, coalesce(p_quantita,1),
     'uscito', p_commessa_id, coalesce(p_ubicazione,''), coalesce(p_note,''), coalesce(p_pagato_intero,true), auth.uid());
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
grant execute on function public.preleva_per_commessa(uuid,uuid,numeric,numeric,numeric,int,text,text,boolean) to authenticated;

-- --- registra_rientro: valorizza l'avanzo in base a pagato_intero del pezzo --
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
language plpgsql security definer set search_path = public
as $$
declare
  v_ruolo  text := public.ruolo_utente();
  v_p      public.magazzino_pezzi;
  v_codice text;
  v_costo  numeric := 0;
  v_val    text := 'zero';
  v_artcosto numeric;
  v_mq     numeric;
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
    -- Valorizzazione automatica: se la lastra era pagata intera dal cliente -> avanzo €0;
    -- altrimenti l'avanzo rientra al costo d'acquisto (mq rientrati x costo articolo).
    if coalesce(v_p.pagato_intero, true) then
      v_costo := 0; v_val := 'zero';
    else
      select costo into v_artcosto from public.articoli where id = v_p.articolo_id;
      v_mq := (coalesce(p_larghezza,0) * coalesce(p_altezza,0) / 10000.0) * coalesce(p_quantita,1);
      v_costo := round(coalesce(v_artcosto,0) * v_mq, 2);
      v_val := 'acquisto';
    end if;
    v_codice := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
    insert into public.magazzino_pezzi
      (codice, articolo_id, pezzo_padre_id, larghezza_cm, altezza_cm, spessore_mm,
       quantita, stato, costo, valorizzazione, ubicazione, note, pagato_intero, creato_da)
    values
      (v_codice, v_p.articolo_id, v_p.id, p_larghezza, p_altezza, p_spessore,
       coalesce(p_quantita,1), 'in_magazzino', v_costo, v_val, coalesce(p_ubicazione,''),
       coalesce(p_note,''), true, auth.uid());
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

-- Fine migrazione v93.
