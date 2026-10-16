-- =====================================================================
--  Migrazione v174 — Dopo la produzione: imballo e "pronta per la spedizione"
--  Quando la produzione chiude l'ultima lavorazione la commessa resta
--  stato 'pronta' (mostrato come "Lavorazione terminata").
--  Il magazziniere prende in carico l'imballo e poi la segna
--  "Pronta per la spedizione": il Back office organizza corriere/ritiro.
--  Non si aggiunge un nuovo stato (lo stato 'pronta' e' usato da impegni,
--  DDT e consuntivi): si registrano solo chi/quando.
-- =====================================================================

alter table public.commesse add column if not exists imballo_da_id     uuid;
alter table public.commesse add column if not exists imballo_da_nome   text;
alter table public.commesse add column if not exists imballo_il        timestamptz;
alter table public.commesse add column if not exists spedibile_da_id   uuid;
alter table public.commesse add column if not exists spedibile_da_nome text;
alter table public.commesse add column if not exists spedibile_il      timestamptz;

-- Azioni del magazzino sull'imballo (il magazziniere non ha i permessi di scrittura
-- su tutta la commessa: passa da qui).
--   'inizio'            -> prendo in carico l'imballo
--   'spedibile'         -> imballata, pronta per la spedizione
--   'annulla_spedibile' -> torna "in imballaggio"
--   'annulla'           -> torna "lavorazione terminata"
create or replace function public.commessa_imballo(p_commessa_id uuid, p_azione text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome  text;
  v_stato text;
begin
  if coalesce(public.ruolo_utente(),'') not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  select nome into v_nome from public.profiles where id = auth.uid();
  select stato into v_stato from public.commesse where id = p_commessa_id;
  if v_stato is null then raise exception 'Commessa non trovata'; end if;

  if p_azione = 'inizio' then
    if v_stato <> 'pronta' then raise exception 'La lavorazione della commessa non e'' ancora terminata'; end if;
    update public.commesse
       set imballo_da_id = auth.uid(), imballo_da_nome = coalesce(v_nome,''), imballo_il = now(),
           spedibile_da_id = null, spedibile_da_nome = null, spedibile_il = null
     where id = p_commessa_id;
  elsif p_azione = 'spedibile' then
    if v_stato <> 'pronta' then raise exception 'La lavorazione della commessa non e'' ancora terminata'; end if;
    update public.commesse
       set imballo_da_id   = coalesce(imballo_da_id, auth.uid()),
           imballo_da_nome = coalesce(imballo_da_nome, v_nome, ''),
           imballo_il      = coalesce(imballo_il, now()),
           spedibile_da_id = auth.uid(), spedibile_da_nome = coalesce(v_nome,''), spedibile_il = now()
     where id = p_commessa_id;
  elsif p_azione = 'annulla_spedibile' then
    update public.commesse set spedibile_da_id = null, spedibile_da_nome = null, spedibile_il = null
     where id = p_commessa_id;
  elsif p_azione = 'annulla' then
    update public.commesse
       set imballo_da_id = null, imballo_da_nome = null, imballo_il = null,
           spedibile_da_id = null, spedibile_da_nome = null, spedibile_il = null
     where id = p_commessa_id;
  else
    raise exception 'Azione sconosciuta: %', p_azione;
  end if;
end;
$$;

grant execute on function public.commessa_imballo(uuid, text) to authenticated;

-- Fine migrazione v174.
