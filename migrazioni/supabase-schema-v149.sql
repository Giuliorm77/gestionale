-- =====================================================================
--  Migrazione v149 — Mappatura scadenze → anagrafica (per P.IVA E/O Codice Fiscale)
--  Collega ogni scadenza al cliente/fornitore del gestionale confrontando sia la
--  P.IVA sia il Codice Fiscale, normalizzati (maiuscole, senza spazi/punti e senza
--  prefisso paese tipo "IT" sulle partite IVA). Così:
--   - P.IVA "IT12345678901" ~ "12345678901"
--   - CF persona fisica 16 caratteri alfanumerici invariato
--   - aziende con P.IVA = CF (11 cifre) combaciano in ogni caso
--  Chiamata dalla sync (fic-sync) e disponibile come azione manuale "Rimappa".
-- =====================================================================

-- colonna per il codice fiscale della controparte (da FIC: entity.tax_code)
alter table public.scadenze add column if not exists controparte_cf text default '';

-- normalizza un identificativo fiscale (P.IVA o CF)
create or replace function public.norm_fiscale(x text)
returns text
language plpgsql
immutable
as $$
declare u text;
begin
  u := upper(coalesce(x,''));
  u := regexp_replace(u, '[^A-Z0-9]', '', 'g');       -- togli spazi, punti, ecc.
  if u ~ '^[A-Z]{2}[0-9]{8,}$' then u := substring(u from 3); end if;  -- togli prefisso paese su P.IVA (es. IT...)
  return nullif(u, '');
end;
$$;

create or replace function public.mappa_scadenze()
returns int
language plpgsql
security definer
set search_path = public
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

grant execute on function public.mappa_scadenze() to authenticated;

-- Fine migrazione v149.
