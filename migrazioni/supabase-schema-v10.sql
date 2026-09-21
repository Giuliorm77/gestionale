-- =====================================================================
--  MIGRAZIONE v10 - ANAGRAFICA FORNITORI (sezione 5.2 del piano)
--  Anagrafica base. Il listino agganciato al catalogo + confronto prezzi
--  sara' un passo successivo.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.fornitori (
  id                 uuid primary key default gen_random_uuid(),
  ragione_sociale    text not null,
  cosa_fornisce      text[] not null default '{}',   -- lavorazioni/categorie coperte
  cosa_fornisce_note text default '',
  affidabilita       int  default 0,                 -- 0..5 stelle
  referente          text default '',
  telefono           text default '',
  cellulare          text default '',
  email              text default '',
  pec                text default '',
  partita_iva        text default '',
  codice_fiscale     text default '',
  codice_sdi         text default '',
  iban               text default '',
  indirizzo          text default '',
  cap                text default '',
  citta              text default '',
  provincia          text default '',
  regione            text default '',
  nazione            text default 'Italia',
  termini_pagamento  text default '',
  note               text default '',
  attivo             boolean not null default true,
  creato_il          timestamptz not null default now(),
  creato_da          uuid references auth.users (id)
);

alter table public.fornitori enable row level security;

drop policy if exists fornitori_select on public.fornitori;
create policy fornitori_select on public.fornitori for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists fornitori_insert on public.fornitori;
create policy fornitori_insert on public.fornitori for insert to authenticated
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists fornitori_update on public.fornitori;
create policy fornitori_update on public.fornitori for update to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists fornitori_delete on public.fornitori;
create policy fornitori_delete on public.fornitori for delete to authenticated
  using (public.ruolo_utente() = 'amministratore');

-- Fine migrazione v10.
