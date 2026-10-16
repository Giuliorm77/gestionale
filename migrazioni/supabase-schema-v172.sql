-- =====================================================================
--  Migrazione v172 — Ore TIMBRATE per fase e operatore (consuntivo reale)
--  Le ore effettive del consuntivo diventano quelle timbrate in Postazione,
--  per l'operatore che ha lavorato davvero (costo orario reale).
--  Questa funzione le somma lato DB (niente limite delle 1000 righe).
--  Solo segmenti CHIUSI (con fine). Dato economico → admin + Back office.
-- =====================================================================

create or replace function public.ore_timbrate_fasi(p_chiavi text[] default null)
returns table(fase_chiave text, operatore_id uuid, operatore_nome text, ore numeric)
language sql
stable
security definer
set search_path = public
as $$
  select s.fase_chiave::text,
         s.operatore_id,
         max(coalesce(s.operatore_nome,''))::text,
         coalesce(sum(extract(epoch from (s.fine - s.inizio)) / 3600.0), 0)::numeric
    from public.segmenti_lavoro s
   where s.fine is not null
     and s.fase_chiave is not null
     and (p_chiavi is null or s.fase_chiave::text = any(p_chiavi))
     and public.ruolo_utente() in ('amministratore','commerciale')
   group by s.fase_chiave, s.operatore_id;
$$;

grant execute on function public.ore_timbrate_fasi(text[]) to authenticated;

-- Fine migrazione v172.
