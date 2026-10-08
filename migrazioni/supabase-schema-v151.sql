-- =====================================================================
--  Migrazione v151 — Performance mappatura/creazione anagrafiche (fix timeout)
--  - norm_fiscale riscritta in SQL IMMUTABLE (inlinabile → molto più veloce)
--  - anagrafiche_da_scadenze: una sola rimappatura, anti-join efficiente,
--    statement_timeout alzato.
-- =====================================================================

-- norm_fiscale in SQL puro (il planner può inlinearla)
create or replace function public.norm_fiscale(x text)
returns text
language sql
immutable
as $$
  select nullif(
    case
      when upper(regexp_replace(coalesce(x,''),'[^A-Za-z0-9]','','g')) ~ '^[A-Z]{2}[0-9]{8,}$'
        then substr(upper(regexp_replace(coalesce(x,''),'[^A-Za-z0-9]','','g')), 3)
      else upper(regexp_replace(coalesce(x,''),'[^A-Za-z0-9]','','g'))
    end, '');
$$;

-- mappa_scadenze con timeout generoso (usa la norm_fiscale ora veloce)
create or replace function public.mappa_scadenze()
returns int
language plpgsql
security definer
set search_path = public
set statement_timeout = '120s'
as $$
declare n1 int; n2 int;
begin
  update public.scadenze s set cliente_id = c.id
  from public.clienti c
  where s.tipo = 'cliente' and s.cliente_id is null
    and (
         (public.norm_fiscale(s.controparte_piva) is not null and public.norm_fiscale(s.controparte_piva) in (public.norm_fiscale(c.partita_iva), public.norm_fiscale(c.codice_fiscale)))
      or (public.norm_fiscale(s.controparte_cf)   is not null and public.norm_fiscale(s.controparte_cf)   in (public.norm_fiscale(c.partita_iva), public.norm_fiscale(c.codice_fiscale)))
    );
  get diagnostics n1 = row_count;

  update public.scadenze s set fornitore_id = f.id
  from public.fornitori f
  where s.tipo = 'fornitore' and s.fornitore_id is null
    and (
         (public.norm_fiscale(s.controparte_piva) is not null and public.norm_fiscale(s.controparte_piva) in (public.norm_fiscale(f.partita_iva), public.norm_fiscale(f.codice_fiscale)))
      or (public.norm_fiscale(s.controparte_cf)   is not null and public.norm_fiscale(s.controparte_cf)   in (public.norm_fiscale(f.partita_iva), public.norm_fiscale(f.codice_fiscale)))
    );
  get diagnostics n2 = row_count;
  return coalesce(n1,0) + coalesce(n2,0);
end;
$$;

-- crea anagrafiche dalle fatture: anti-join su chiave normalizzata, 1 sola rimappatura
create or replace function public.anagrafiche_da_scadenze(p_tipo text default 'both')
returns json
language plpgsql
security definer
set search_path = public
set statement_timeout = '120s'
as $$
declare nc int := 0; nf int := 0;
begin
  if p_tipo in ('cliente','both') then
    with esist as (
      select distinct coalesce(public.norm_fiscale(partita_iva), public.norm_fiscale(codice_fiscale), lower(ragione_sociale)) k
      from public.clienti
    ),
    cand as (
      select distinct on (k) nome, piva, cf, k from (
        select controparte_nome as nome, coalesce(controparte_piva,'') as piva, coalesce(controparte_cf,'') as cf,
               coalesce(public.norm_fiscale(controparte_piva), public.norm_fiscale(controparte_cf), lower(controparte_nome)) as k
        from public.scadenze where tipo='cliente' and coalesce(controparte_nome,'') <> ''
      ) s order by k, nome
    )
    insert into public.clienti (ragione_sociale, partita_iva, codice_fiscale, categoria, stato)
    select nome, piva, cf, 'Cliente finale', 'Attivo' from cand
    where k is not null and k not in (select k from esist where k is not null);
    get diagnostics nc = row_count;
  end if;

  if p_tipo in ('fornitore','both') then
    with esist as (
      select distinct coalesce(public.norm_fiscale(partita_iva), public.norm_fiscale(codice_fiscale), lower(ragione_sociale)) k
      from public.fornitori
    ),
    cand as (
      select distinct on (k) nome, piva, cf, k from (
        select controparte_nome as nome, coalesce(controparte_piva,'') as piva, coalesce(controparte_cf,'') as cf,
               coalesce(public.norm_fiscale(controparte_piva), public.norm_fiscale(controparte_cf), lower(controparte_nome)) as k
        from public.scadenze where tipo='fornitore' and coalesce(controparte_nome,'') <> ''
      ) s order by k, nome
    )
    insert into public.fornitori (ragione_sociale, partita_iva, codice_fiscale)
    select nome, piva, cf from cand
    where k is not null and k not in (select k from esist where k is not null);
    get diagnostics nf = row_count;
  end if;

  perform public.mappa_scadenze();
  return json_build_object('clienti_creati', nc, 'fornitori_creati', nf);
end;
$$;

grant execute on function public.anagrafiche_da_scadenze(text) to authenticated;
grant execute on function public.mappa_scadenze() to authenticated;

-- Fine migrazione v151.
