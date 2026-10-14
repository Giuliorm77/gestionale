-- =====================================================================
--  Migrazione v165 — Prelievo che CONSUMA un pannello a scaffale (Fase 2)
--  Per le lastre/pannelli gestiti a pezzi: il prelievo per la commessa NON
--  crea un pezzo nuovo e NON scarica la giacenza sfusa; prende un pezzo
--  esistente 'in_magazzino' (scelto dalla lista o scansionato) e lo manda
--  'uscito' agganciato alla commessa. L'avanzo rientra poi come pezzo figlio
--  (RientroForm, già esistente). La giacenza della lastra = somma dei pezzi.
-- =====================================================================

create or replace function public.preleva_pezzo_commessa(
  p_pezzo_id      uuid,
  p_commessa_id   uuid,
  p_pagato_intero boolean default null,
  p_note          text    default null
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruolo  text := public.ruolo_utente();
  v_codice text;
  v_stato  text;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  select codice, stato into v_codice, v_stato
    from public.magazzino_pezzi where id = p_pezzo_id;
  if not found then raise exception 'Pannello non trovato'; end if;
  if v_stato <> 'in_magazzino' then
    raise exception 'Il pannello non è disponibile (stato: %)', v_stato;
  end if;
  update public.magazzino_pezzi
     set stato = 'uscito',
         commessa_id = p_commessa_id,
         pagato_intero = coalesce(p_pagato_intero, pagato_intero),
         note = case when p_note is not null and p_note <> '' then p_note else note end
   where id = p_pezzo_id;
  return v_codice;
end;
$$;

grant execute on function public.preleva_pezzo_commessa(uuid,uuid,boolean,text) to authenticated;

-- Funzione di servizio: giacenza "a pezzi" per una lista di articoli
-- (somma mq e conteggio dei pezzi 'in_magazzino'). Usata dalla lista Magazzino
-- per mostrare la giacenza delle lastre come somma dei pannelli a scaffale.
create or replace function public.giacenza_pezzi(p_ids uuid[])
returns table(articolo_id uuid, n_pezzi bigint, mq numeric)
language sql
stable
security definer
set search_path = public
as $$
  select p.articolo_id,
         count(*)::bigint,
         coalesce(sum((coalesce(p.larghezza_cm,0)*coalesce(p.altezza_cm,0)/10000.0)*coalesce(p.quantita,1)),0)::numeric
    from public.magazzino_pezzi p
   where p.stato = 'in_magazzino'
     and p.articolo_id = any(p_ids)
     and public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione')
   group by p.articolo_id;
$$;

grant execute on function public.giacenza_pezzi(uuid[]) to authenticated;

-- Fine migrazione v165.
