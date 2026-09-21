-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v8  (carosello foto della homepage)
--
--  COSA FA (tutto ADDITIVO):
--   tabella komunigo_carosello: le foto larghe che scorrono in loop nella
--   banda sotto l'hero della homepage, gestite dal gestionale.
--   Le foto vivono nel bucket pubblico komunigo-public (creato in v2).
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.komunigo_carosello (
  id          uuid primary key default gen_random_uuid(),
  titolo      text not null default '',
  sottotitolo text not null default '',
  path        text,                       -- foto (larga ~16:6) nel bucket komunigo-public
  ordine      int  not null default 0,
  attivo      boolean not null default true,
  creato_il   timestamptz not null default now()
);

comment on table public.komunigo_carosello is
  'Foto del carosello a scorrimento della homepage Komunigo.';

alter table public.komunigo_carosello enable row level security;
drop policy if exists komunigo_carosello_all on public.komunigo_carosello;
create policy komunigo_carosello_all on public.komunigo_carosello for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop view if exists public.komunigo_carosello_pub;
create view public.komunigo_carosello_pub as
select id, titolo, sottotitolo, path, ordine
from public.komunigo_carosello
where attivo = true;
grant select on public.komunigo_carosello_pub to anon, authenticated;

-- Fine migrazione Komunigo v8.
