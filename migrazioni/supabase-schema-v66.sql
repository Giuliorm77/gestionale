-- =====================================================================
--  MIGRAZIONE v66 - RINNOVO LISTINO FORNITORE
--
--  I listini dei fornitori (soprattutto gadget) cambiano ~ogni 6 mesi:
--  nuovi prezzi, articoli aggiunti, articoli tolti. L'import intelligente
--  gia' aggiorna i prezzi e aggiunge i nuovi. Questa funzione chiude il
--  cerchio sui TOLTI: gli articoli di quel fornitore NON piu' presenti nel
--  file nuovo vengono DISATTIVATi (spariscono dai menu, storico salvo), e
--  quelli MAI USATI (nessun riferimento da nessuna parte) vengono eliminati.
--
--  "di quel fornitore" = collegati in articoli_fornitori a quel fornitore.
--  Sicura: NON cancella mai un articolo referenziato (preventivi, commesse,
--  ordini, interventi, prodotti config, pezzi, movimenti) -> lo storico resta.
--
--  Solo amministratore.
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create or replace function public.rinnova_listino_fornitore(
  p_fornitore_id uuid,
  p_codici       text[]
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruolo       text := public.ruolo_utente();
  v_disattivati int  := 0;
  v_eliminati   int  := 0;
begin
  if v_ruolo is null or v_ruolo <> 'amministratore' then
    raise exception 'Solo l''amministratore puo'' rinnovare un listino';
  end if;

  -- articoli di questo fornitore NON presenti nel file nuovo (per codice)
  create temporary table _fuori on commit drop as
    select distinct a.id, a.codice
    from public.articoli a
    join public.articoli_fornitori af on af.articolo_id = a.id
    where af.fornitore_id = p_fornitore_id
      and (a.codice is null or not (a.codice = any(p_codici)));

  -- 1) disattiva tutti i "fuori listino"
  update public.articoli set attivo = false, aggiornato_il = now()
   where id in (select id from _fuori);
  get diagnostics v_disattivati = row_count;

  -- 2) elimina SOLO quelli mai usati (nessun riferimento -> lo storico non si tocca)
  delete from public.articoli a
   where a.id in (select id from _fuori)
     and not exists (select 1 from public.preventivi_righe       x where x.articolo_id = a.id)
     and not exists (select 1 from public.commesse_righe         x where x.articolo_id = a.id)
     and not exists (select 1 from public.ordini_fornitore_righe x where x.articolo_id = a.id)
     and not exists (select 1 from public.interventi_righe       x where x.articolo_id = a.id)
     and not exists (select 1 from public.prodotti_config          x where x.materiale_id = a.id)
     and not exists (select 1 from public.prodotti_config_varianti x where x.articolo_id  = a.id)
     and not exists (select 1 from public.magazzino_pezzi        x where x.articolo_id = a.id)
     and not exists (select 1 from public.movimenti_magazzino    x where x.articolo_id = a.id);
  get diagnostics v_eliminati = row_count;

  return jsonb_build_object('disattivati', v_disattivati, 'eliminati', v_eliminati);
end;
$$;

grant execute on function public.rinnova_listino_fornitore(uuid, text[]) to authenticated;

-- Fine migrazione v66.
