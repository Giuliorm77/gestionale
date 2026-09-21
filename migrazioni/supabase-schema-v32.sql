-- =====================================================================
--  MIGRAZIONE v32 - Sedi multiple del fornitore (sede legale, magazzino,
--  uffici...) con giorni di chiusura e orari.
--
--  Come per i clienti (clienti_sedi). L'indirizzo "principale" sui campi
--  della tabella fornitori viene tenuto allineato dall'app alla SEDE LEGALE
--  (o alla prima sede), cosi' il resto del gestionale (PDF ordine, ricerche)
--  continua a funzionare senza modifiche.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.fornitori_sedi (
  id            uuid primary key default gen_random_uuid(),
  fornitore_id  uuid not null references public.fornitori (id) on delete cascade,
  tipo          text default 'legale',        -- legale / magazzino / uffici / operativa / altro
  indirizzo     text default '',
  cap           text default '',
  citta         text default '',
  provincia     text default '',
  regione       text default '',
  nazione       text default 'Italia',
  giorni_chiusura   text[] default '{}',       -- es. {Sab,Dom}
  orario_mattino    text default '',
  orario_pomeriggio text default '',
  note          text default ''                -- es. chiusura ferie agosto
);
create index if not exists fornitori_sedi_idx on public.fornitori_sedi (fornitore_id);

-- RLS: come i fornitori -> amministratore e commerciale
alter table public.fornitori_sedi enable row level security;

drop policy if exists fornitori_sedi_all on public.fornitori_sedi;
create policy fornitori_sedi_all on public.fornitori_sedi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v32.
