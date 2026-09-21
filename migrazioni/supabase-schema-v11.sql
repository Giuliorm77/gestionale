-- =====================================================================
--  MIGRAZIONE v11 - IMPOSTAZIONI (parametri prezzo + tariffe lavorazioni)
--  Il "cervello prezzi" usato dai Preventivi:
--   - parametri generali: spese generali %, margine minimo (soglia), IVA %
--   - per ogni lavorazione: tariffa oraria "piena" + margine obiettivo
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- Parametri generali: una sola riga (id sempre = 1)
create table if not exists public.impostazioni (
  id                 int primary key default 1,
  spese_generali_pct numeric default 0,
  margine_minimo_pct numeric default 0,
  iva_pct            numeric default 22,
  constraint impostazioni_singleton check (id = 1)
);
insert into public.impostazioni (id) values (1) on conflict do nothing;

-- Tariffe per lavorazione
create table if not exists public.impostazioni_lavorazioni (
  id                uuid primary key default gen_random_uuid(),
  lavorazione       text not null unique,
  tariffa_oraria    numeric default 0,   -- tariffa "piena" (macchina + quota costi fissi)
  margine_obiettivo numeric default 0    -- % obiettivo per questa lavorazione
);

alter table public.impostazioni             enable row level security;
alter table public.impostazioni_lavorazioni enable row level security;

drop policy if exists impostazioni_all on public.impostazioni;
create policy impostazioni_all on public.impostazioni for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists imp_lav_all on public.impostazioni_lavorazioni;
create policy imp_lav_all on public.impostazioni_lavorazioni for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v11.
