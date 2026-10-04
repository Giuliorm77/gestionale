-- =====================================================================
--  Migrazione v128 — Registro modifiche a commessa CHIUSA (post-produzione)
--  - contatore "modifiche_post_chiusura" sulla commessa: visibile a tutti
--    (si vede CHE è stata modificata N volte, ma non cosa).
--  - tabella commesse_modifiche con il DETTAGLIO (chi/quando/motivo + diff):
--    leggibile SOLO dall'amministratore (RLS); inserita da chi sblocca.
--  Additiva e reversibile.
-- =====================================================================

alter table public.commesse
  add column if not exists modifiche_post_chiusura integer not null default 0;

create table if not exists public.commesse_modifiche (
  id          uuid primary key default gen_random_uuid(),
  commessa_id uuid references public.commesse(id) on delete cascade,
  utente_id   uuid,
  utente_nome text,
  data        timestamptz default now(),
  motivo      text,
  dettaglio   text
);
create index if not exists idx_commesse_modifiche_comm on public.commesse_modifiche(commessa_id);

alter table public.commesse_modifiche enable row level security;
-- Lettura del DETTAGLIO: solo amministratore
drop policy if exists cm_sel_admin on public.commesse_modifiche;
create policy cm_sel_admin on public.commesse_modifiche for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.ruolo = 'amministratore'));
-- Inserimento: chi è autenticato (lo sblocco è già limitato in app ai ruoli economici)
drop policy if exists cm_ins on public.commesse_modifiche;
create policy cm_ins on public.commesse_modifiche for insert to authenticated with check (true);

-- Fine migrazione v128.
-- (Per annullare:
--   drop table if exists public.commesse_modifiche;
--   alter table public.commesse drop column modifiche_post_chiusura;)
