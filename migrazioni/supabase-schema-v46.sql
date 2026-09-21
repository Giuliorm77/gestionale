-- =====================================================================
--  MIGRAZIONE v46 - PERMESSI PER UTENTE + blindatura economica (RLS)
--
--  1) profiles.permessi (jsonb): deroghe per singolo utente rispetto al ruolo.
--     Es. {"economici":true,"elimina":false,"moduli":{"report":false}}
--  2) puo_economici(): true se il ruolo dà l'economico O l'utente ha la
--     deroga economici=true; false se la deroga e' false. Usata dalle RLS.
--  3) Le tabelle INTERAMENTE economiche vengono blindate con puo_economici()
--     (protezione vera lato database, non solo UI): si rimuovono le vecchie
--     policy e se ne mette una sola basata su puo_economici().
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
--  NB: tocca SOLO tabelle interamente economiche (la produzione non le usa).
-- =====================================================================

alter table public.profiles add column if not exists permessi jsonb;

-- economico effettivo dell'utente collegato: deroga per-utente, altrimenti ruolo
create or replace function public.puo_economici()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (select nullif(p.permessi->>'economici','')::boolean
       from public.profiles p
      where p.id = auth.uid()),
    (public.ruolo_utente() in ('amministratore','commerciale'))
  );
$$;
grant execute on function public.puo_economici() to authenticated;

-- ------- Blindatura RLS delle tabelle interamente economiche -------
do $$
declare t text; pol record;
begin
  foreach t in array array[
    'clienti_condizioni','clienti_listini',
    'listini','listini_voci',
    'impostazioni_lavorazioni',
    'articoli_fornitori',
    'preventivi','preventivi_righe',
    'ordini_fornitore','ordini_fornitore_righe',
    'corrieri','corrieri_scaglioni',
    'interventi','interventi_righe'
  ]
  loop
    -- rimuove TUTTE le policy esistenti su quella tabella
    for pol in select policyname from pg_policies where schemaname='public' and tablename=t loop
      execute format('drop policy if exists %I on public.%I', pol.policyname, t);
    end loop;
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I_econ on public.%I for all to authenticated using (public.puo_economici()) with check (public.puo_economici())',
      t, t);
  end loop;
end $$;

-- Fine migrazione v46.
