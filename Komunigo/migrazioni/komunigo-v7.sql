-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v7  (foto "Lavori installati" della homepage)
--
--  COSA FA (tutto ADDITIVO):
--   tabella komunigo_lavori: le foto reali dei lavori mostrate in homepage
--   nella sezione "Fatti da noi, installati da noi", gestite dal gestionale.
--   Le foto vivono nel bucket pubblico komunigo-public (creato in v2).
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.komunigo_lavori (
  id          uuid primary key default gen_random_uuid(),
  titolo      text not null default '',
  sottotitolo text not null default '',
  path        text,                       -- foto nel bucket komunigo-public
  ordine      int  not null default 0,
  attivo      boolean not null default true,
  creato_il   timestamptz not null default now()
);

comment on table public.komunigo_lavori is
  'Foto dei lavori installati mostrate nella homepage Komunigo.';

alter table public.komunigo_lavori enable row level security;
drop policy if exists komunigo_lavori_all on public.komunigo_lavori;
create policy komunigo_lavori_all on public.komunigo_lavori for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop view if exists public.komunigo_lavori_pub;
create view public.komunigo_lavori_pub as
select id, titolo, sottotitolo, path, ordine
from public.komunigo_lavori
where attivo = true;
grant select on public.komunigo_lavori_pub to anon, authenticated;

-- Fine migrazione Komunigo v7.
