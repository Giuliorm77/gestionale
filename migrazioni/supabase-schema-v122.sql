-- =====================================================================
--  Migrazione v122 — File di stampa / grafici della commessa per la produzione
--  Due modi: file caricato nel cloud (bucket privato) OPPURE link alla cartella
--  del server (per i file enormi). Visibili in commessa e in Postazione.
--  Additiva e reversibile.
-- =====================================================================

create table if not exists public.commesse_file (
  id          uuid primary key default gen_random_uuid(),
  commessa_id uuid references public.commesse(id) on delete cascade,
  tipo        text not null default 'file',   -- 'file' (upload) | 'link' (percorso server/url)
  nome        text,
  path        text,                           -- percorso nello storage (tipo 'file')
  url         text,                           -- link/percorso server (tipo 'link')
  caricato_da uuid,
  caricato_il timestamptz default now()
);
create index if not exists idx_commesse_file_comm on public.commesse_file(commessa_id);

alter table public.commesse_file enable row level security;
drop policy if exists commesse_file_all on public.commesse_file;
create policy commesse_file_all on public.commesse_file for all to authenticated using (true) with check (true);

-- Bucket privato per i file caricati
insert into storage.buckets (id, name, public)
values ('commesse-file','commesse-file', false)
on conflict (id) do nothing;

drop policy if exists "commfile_sel" on storage.objects;
drop policy if exists "commfile_ins" on storage.objects;
drop policy if exists "commfile_upd" on storage.objects;
drop policy if exists "commfile_del" on storage.objects;
create policy "commfile_sel" on storage.objects for select to authenticated using (bucket_id = 'commesse-file');
create policy "commfile_ins" on storage.objects for insert to authenticated with check (bucket_id = 'commesse-file');
create policy "commfile_upd" on storage.objects for update to authenticated using (bucket_id = 'commesse-file') with check (bucket_id = 'commesse-file');
create policy "commfile_del" on storage.objects for delete to authenticated using (bucket_id = 'commesse-file');

-- Fine migrazione v122.
-- (Per annullare:
--   drop table if exists public.commesse_file;
--   delete from storage.buckets where id='commesse-file';  -- svuota prima il bucket)
