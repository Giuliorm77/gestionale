-- =====================================================================
--  Migrazione v126 — Ricezione merce lato MAGAZZINO (senza vedere i prezzi)
--  RPC security-definer: il magazziniere, dalla vista "Materiale in arrivo",
--  segna un ordine come ricevuto -> carico a magazzino delle quantità mancanti,
--  righe a ricevuto, ordine a 'ricevuto'. Non tocca/espone i prezzi.
--  Additiva e reversibile.
-- =====================================================================

create or replace function public.ricevi_materiale(p_ordine_id uuid)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_num text; v_rif text; v_n int := 0; r record; v_delta numeric; v_uid uuid := auth.uid();
begin
  select numero into v_num from public.ordini_fornitore where id = p_ordine_id;
  if v_num is null then raise exception 'Ordine non trovato'; end if;
  v_rif := 'Ordine ' || coalesce(v_num,'');
  for r in
    select id, articolo_id, coalesce(quantita,0) q, coalesce(quantita_ricevuta,0) qr
    from public.ordini_fornitore_righe
    where ordine_id = p_ordine_id and articolo_id is not null
  loop
    v_delta := r.q - r.qr;
    if v_delta > 0 then
      insert into public.movimenti_magazzino(articolo_id, tipo, quantita, causale, riferimento, creato_da)
        values (r.articolo_id, 'carico', v_delta, 'Acquisto / carico fornitore', v_rif, v_uid);
      update public.ordini_fornitore_righe set quantita_ricevuta = r.q where id = r.id;
      v_n := v_n + 1;
    end if;
  end loop;
  update public.ordini_fornitore set stato = 'ricevuto', aggiornato_il = now() where id = p_ordine_id;
  return v_n;
end;
$$;
grant execute on function public.ricevi_materiale(uuid) to authenticated;

-- Fine migrazione v126.
-- (Per annullare: drop function if exists public.ricevi_materiale(uuid);)
