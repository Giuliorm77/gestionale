-- =====================================================================
--  MIGRAZIONE v2 - Campi aggiuntivi Anagrafica Clienti
--  (tipo, referente, stato, trasporto, pagamento/banca, listini multipli)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> New query -> Run.
--  E' sicura da ri-eseguire: usa "if not exists".
-- =====================================================================

-- --- Nuovi campi anagrafici (non sensibili) sulla tabella clienti ---
alter table public.clienti add column if not exists tipo             text not null default 'Azienda';
alter table public.clienti add column if not exists referente        text default '';
alter table public.clienti add column if not exists stato            text not null default 'Attivo';
alter table public.clienti add column if not exists trasp_vettore    text default '';
alter table public.clienti add column if not exists trasp_referente  text default '';
alter table public.clienti add column if not exists trasp_telefono   text default '';
alter table public.clienti add column if not exists trasp_resa       text default '';
alter table public.clienti add column if not exists trasp_note       text default '';

-- --- Dati economici/bancari SENSIBILI: nella tabella gia protetta da RLS ---
alter table public.clienti_condizioni add column if not exists banca             text default '';
alter table public.clienti_condizioni add column if not exists iban              text default '';
alter table public.clienti_condizioni add column if not exists metodo_pagamento  text default '';
alter table public.clienti_condizioni add column if not exists termini_pagamento text default '';

-- --- Listini multipli per cliente (ognuno con la sua %) - dati economici ---
create table if not exists public.clienti_listini (
  id          uuid primary key default gen_random_uuid(),
  cliente_id  uuid not null references public.clienti (id) on delete cascade,
  nome        text not null default '',
  sconto      numeric(5,2) default 0
);
alter table public.clienti_listini enable row level security;

drop policy if exists clienti_listini_select on public.clienti_listini;
create policy clienti_listini_select on public.clienti_listini for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists clienti_listini_write on public.clienti_listini;
create policy clienti_listini_write on public.clienti_listini for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v2.
