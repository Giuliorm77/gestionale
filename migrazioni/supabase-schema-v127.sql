-- =====================================================================
--  Migrazione v127 — Auto "pronto" quando la produzione chiude le lavorazioni
--  Quando TUTTE le fasi di una commessa sono "fatto", la commessa passa a
--  "pronta" E gli articoli ancora da produrre passano a "pronto" (spedibili).
--  RPC security-definer (funziona anche per la produzione, che non ha write).
--  Additiva e reversibile.
-- =====================================================================

create or replace function public.commessa_segna_pronta(p_commessa_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_all boolean; v_stato text;
begin
  select stato into v_stato from public.commesse where id = p_commessa_id;
  if v_stato is null or v_stato in ('consegnata','chiusa') then return false; end if;
  -- tutte le fasi fatte? (almeno una fase e nessuna diversa da 'fatto')
  select (count(*) > 0 and count(*) filter (where stato <> 'fatto') = 0) into v_all
    from public.commesse_fasi where commessa_id = p_commessa_id;
  if not v_all then return false; end if;
  update public.commesse set stato = 'pronta', aggiornato_il = now()
    where id = p_commessa_id and stato not in ('consegnata','chiusa');
  update public.commesse_righe set stato = 'pronto'
    where commessa_id = p_commessa_id and stato in ('da_produrre','in_produzione');
  return true;
end;
$$;
grant execute on function public.commessa_segna_pronta(uuid) to authenticated;

-- Fine migrazione v127.
-- (Per annullare: drop function if exists public.commessa_segna_pronta(uuid);)
