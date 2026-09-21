-- =====================================================================
--  MIGRAZIONE v59 - LISTINO UNICO + SCONTI (standard + eccezioni per categoria)
--
--  Modello deciso: il prezzo di listino e' UNO SOLO (articoli.prezzo_pubblico).
--  Quello che cambia da cliente a cliente e' lo SCONTO:
--    1) eccezione per categoria di articolo  (clienti_sconti)
--    2) altrimenti sconto standard del cliente (clienti.sconto_pct)
--    3) altrimenti, se il cliente e' "Rivenditore", lo sconto standard
--       rivenditori (impostazioni.sconto_rivenditori_pct)
--    4) altrimenti 0
--
--  NB: i vecchi campi articoli.prezzo_rivenditori / prezzo_riservato NON
--  vengono toccati (scelta dell'utente: restano finche' non siamo sicuri).
--  Anche la vecchia tabella clienti_listini resta, ma non e' piu' usata dalla UI.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- 1. Sconto standard del cliente (NULL = usa il default della sua categoria)
alter table public.clienti add column if not exists sconto_pct numeric;

-- 2. Sconto standard per i clienti marcati "Rivenditore"
alter table public.impostazioni add column if not exists sconto_rivenditori_pct numeric default 0;

-- 3. Eccezioni di sconto per categoria di articolo
create table if not exists public.clienti_sconti (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clienti(id) on delete cascade,
  categoria text not null,
  sconto_pct numeric default 0
);
create index if not exists clienti_sconti_cliente_idx on public.clienti_sconti(cliente_id);

alter table public.clienti_sconti enable row level security;

drop policy if exists clienti_sconti_select on public.clienti_sconti;
create policy clienti_sconti_select on public.clienti_sconti for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists clienti_sconti_write on public.clienti_sconti;
create policy clienti_sconti_write on public.clienti_sconti for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v59.
