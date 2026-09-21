-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v4  (ordini + upload file grafici del cliente)
--
--  COSA FA (tutto ADDITIVO):
--   1) aggiunge komunigo_ordini.token (uuid) per recuperare l'ordine senza
--      login (pagina "i tuoi ordini" via ?token=...).
--   2) tabella komunigo_ordini_file: i file grafici caricati dal cliente,
--      legati all'ordine e alla riga. Scrivibile solo dal server.
--   3) bucket Storage PRIVATO komunigo-ordini: i file NON sono pubblici;
--      upload via signed URL (rilasciato dalla Edge Function) e download via
--      signed URL. Lettura diretta consentita solo allo staff.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---- 1) token dell'ordine (per il recupero pubblico senza login) ----
alter table public.komunigo_ordini
  add column if not exists token uuid not null default gen_random_uuid();
create unique index if not exists komunigo_ordini_token_idx
  on public.komunigo_ordini (token);

-- ---- 2) file grafici caricati dal cliente ----
create table if not exists public.komunigo_ordini_file (
  id             uuid primary key default gen_random_uuid(),
  ordine_id      uuid not null references public.komunigo_ordini (id) on delete cascade,
  ordine_riga_id uuid references public.komunigo_ordini_righe (id) on delete cascade,
  path           text not null,               -- percorso nel bucket komunigo-ordini
  nome_file      text not null,
  dimensione     bigint,
  mime           text,
  stato          text not null default 'caricato'
                 check (stato in ('caricato','in_verifica','approvato','rifiutato')),
  note           text not null default '',
  creato_il      timestamptz not null default now()
);
create index if not exists ko_file_ordine_idx on public.komunigo_ordini_file (ordine_id);

comment on table public.komunigo_ordini_file is
  'File grafici caricati dal cliente per un ordine Komunigo (nel bucket privato komunigo-ordini).';

alter table public.komunigo_ordini_file enable row level security;
-- Nessuna policy anon: scrive solo il server (service_role). Lo staff può leggere
-- l'elenco file (per il futuro pannello ordini nel gestionale).
drop policy if exists komunigo_ordini_file_staff on public.komunigo_ordini_file;
create policy komunigo_ordini_file_staff on public.komunigo_ordini_file for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione'));

-- ---- 3) bucket PRIVATO per i file degli ordini ----
insert into storage.buckets (id, name, public)
values ('komunigo-ordini', 'komunigo-ordini', false)
on conflict (id) do update set public = false;

-- Nessuna policy per anon: l'upload avviene con SIGNED URL rilasciato dalla
-- Edge Function (service_role), che bypassa la RLS. Lo staff può leggere/scaricare
-- direttamente i file dal gestionale.
drop policy if exists komunigo_ordini_files_staff on storage.objects;
create policy komunigo_ordini_files_staff on storage.objects for select to authenticated
  using (bucket_id = 'komunigo-ordini' and public.ruolo_utente() in ('amministratore','commerciale','produzione'));

-- Fine migrazione Komunigo v4.
