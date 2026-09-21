-- =====================================================================
--  MIGRAZIONE v7 - OPERATORI / RISORSE (sezione 5.4 del piano)
--  Registro delle persone con COSTO ORARIO per reparto.
--  I Preventivi pescheranno da qui la manodopera.
--
--  Il costo orario e' un DATO SENSIBILE: la tabella e' visibile solo ai
--  ruoli economici (amministratore, commerciale). L'apertura alla
--  Produzione (nomi si', costo no) la faremo separando i costi in seguito.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.operatori (
  id           uuid primary key default gen_random_uuid(),
  nome         text not null default '',
  reparto      text default '',                 -- una delle lavorazioni
  costo_orario numeric(10,2) default 0,         -- DATO SENSIBILE
  attivo       boolean not null default true,
  note         text default '',
  creato_il    timestamptz not null default now()
);
create index if not exists operatori_reparto_idx on public.operatori (reparto);

alter table public.operatori enable row level security;

drop policy if exists operatori_select on public.operatori;
create policy operatori_select on public.operatori for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists operatori_write on public.operatori;
create policy operatori_write on public.operatori for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v7.
