-- =====================================================================
--  Migrazione v150 — Crea anagrafiche dalle FATTURE (scadenzario)
--  Molti clienti/fornitori sono destinatari di fattura NON salvati nella rubrica
--  di FIC: la fonte completa sono le scadenze. Questa RPC crea le anagrafiche
--  mancanti pescando le controparti distinte dalle scadenze non mappate
--  (dedup per P.IVA/CF normalizzati, o per nome se manca il codice), poi rimappa.
--  p_tipo: 'cliente' | 'fornitore' | 'both'
-- =====================================================================

create or replace function public.anagrafiche_da_scadenze(p_tipo text default 'both')
returns json
language plpgsql
security definer
set search_path = public
as $$
declare nc int := 0; nf int := 0;
begin
  if p_tipo in ('cliente','both') then
    perform public.mappa_scadenze();   -- collega prima a chi già esiste
    insert into public.clienti (ragione_sociale, partita_iva, codice_fiscale, categoria, stato)
    select nome, piva, cf, 'Cliente finale', 'Attivo'
    from (
      select distinct on (coalesce(public.norm_fiscale(controparte_piva), public.norm_fiscale(controparte_cf), lower(controparte_nome)))
        controparte_nome as nome, coalesce(controparte_piva,'') as piva, coalesce(controparte_cf,'') as cf
      from public.scadenze
      where tipo='cliente' and cliente_id is null and coalesce(controparte_nome,'') <> ''
      order by coalesce(public.norm_fiscale(controparte_piva), public.norm_fiscale(controparte_cf), lower(controparte_nome)), controparte_nome
    ) q;
    get diagnostics nc = row_count;
    perform public.mappa_scadenze();   -- collega i nuovi
  end if;

  if p_tipo in ('fornitore','both') then
    perform public.mappa_scadenze();
    insert into public.fornitori (ragione_sociale, partita_iva, codice_fiscale)
    select nome, piva, cf
    from (
      select distinct on (coalesce(public.norm_fiscale(controparte_piva), public.norm_fiscale(controparte_cf), lower(controparte_nome)))
        controparte_nome as nome, coalesce(controparte_piva,'') as piva, coalesce(controparte_cf,'') as cf
      from public.scadenze
      where tipo='fornitore' and fornitore_id is null and coalesce(controparte_nome,'') <> ''
      order by coalesce(public.norm_fiscale(controparte_piva), public.norm_fiscale(controparte_cf), lower(controparte_nome)), controparte_nome
    ) q;
    get diagnostics nf = row_count;
    perform public.mappa_scadenze();
  end if;

  return json_build_object('clienti_creati', nc, 'fornitori_creati', nf);
end;
$$;

grant execute on function public.anagrafiche_da_scadenze(text) to authenticated;

-- Fine migrazione v150.
