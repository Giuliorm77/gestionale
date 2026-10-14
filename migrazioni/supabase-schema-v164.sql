-- =====================================================================
--  Migrazione v164 — Carico pannelli a misura (Magazzino a pezzi, Fase 1)
--  Crea a scaffale N pezzi tracciati (stato 'in_magazzino') per un pannello/
--  lastra, con base × altezza × spessore + costo. Ogni pezzo ha il suo codice
--  (etichetta QR). NON tocca la giacenza "sfusa" in mq: il valore di questi
--  pannelli è contato una sola volta, come "pezzi a scaffale" nella
--  valorizzazione_magazzino (v142). La Fase 2 collegherà il prelievo in
--  commessa al consumo del pezzo.
-- =====================================================================

create or replace function public.carica_pannelli(
  p_articolo_id    uuid,
  p_larghezza      numeric,            -- cm
  p_altezza        numeric,            -- cm
  p_spessore       numeric default null, -- mm
  p_quantita       int     default 1,
  p_costo_unitario numeric default null, -- € per pannello
  p_ubicazione     text    default '',
  p_note           text    default ''
) returns text[]
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  v_cod   text;
  v_out   text[] := '{}';
  v_val   text;
  i       int;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale') then
    raise exception 'Non autorizzato';
  end if;
  if p_articolo_id is null then raise exception 'Articolo mancante'; end if;
  v_val := case when p_costo_unitario is null then 'manuale'
                when p_costo_unitario = 0   then 'zero'
                else 'acquisto' end;
  for i in 1..greatest(coalesce(p_quantita,1),1) loop
    v_cod := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
    insert into public.magazzino_pezzi
      (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
       costo, valorizzazione, stato, ubicazione, note, creato_da)
    values
      (v_cod, p_articolo_id, p_larghezza, p_altezza, p_spessore, 1,
       p_costo_unitario, v_val, 'in_magazzino', coalesce(p_ubicazione,''), coalesce(p_note,''), auth.uid());
    v_out := array_append(v_out, v_cod);
  end loop;
  return v_out;
end;
$$;

grant execute on function public.carica_pannelli(uuid,numeric,numeric,numeric,int,numeric,text,text) to authenticated;

-- Fine migrazione v164.
