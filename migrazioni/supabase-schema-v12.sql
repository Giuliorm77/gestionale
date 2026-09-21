-- =====================================================================
--  MIGRAZIONE v12 - APPROVAZIONE UTENTI
--  Un nuovo utente registrato resta "in attesa": non puo' leggere ne'
--  scrivere NULLA finche' un amministratore non lo approva.
--  Il blocco e' applicato dal DATABASE (non solo dall'interfaccia).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- 1) Campo "approvato" sul profilo
alter table public.profiles add column if not exists approvato boolean not null default false;

-- Gli utenti GIA' esistenti (incluso l'amministratore) restano approvati
update public.profiles set approvato = true where approvato = false;
-- Nota: i nuovi utenti creati d'ora in poi partiranno con approvato = false (default).

-- 2) ruolo_utente() restituisce il ruolo SOLO se l'utente e' approvato.
--    Cosi' tutte le policy basate sul ruolo negano l'accesso ai non approvati.
create or replace function public.ruolo_utente()
returns text language sql stable security definer set search_path = public as $$
  select case when approvato then ruolo else null end
  from public.profiles where id = auth.uid();
$$;

-- 3) Le tabelle con lettura "aperta a tutti gli autenticati" ora richiedono
--    un utente APPROVATO (ruolo non nullo).
drop policy if exists clienti_select on public.clienti;
create policy clienti_select on public.clienti for select to authenticated
  using (public.ruolo_utente() is not null);

drop policy if exists sedi_select on public.clienti_sedi;
create policy sedi_select on public.clienti_sedi for select to authenticated
  using (public.ruolo_utente() is not null);

drop policy if exists email_select on public.clienti_email;
create policy email_select on public.clienti_email for select to authenticated
  using (public.ruolo_utente() is not null);

drop policy if exists listini_select on public.listini;
create policy listini_select on public.listini for select to authenticated
  using (public.ruolo_utente() is not null);

-- (Le altre tabelle economiche erano gia' limitate per ruolo: con ruolo NULL
--  i non approvati vengono automaticamente esclusi.)

-- Il profilo proprio resta leggibile dall'utente (serve all'app per sapere
--  che e' "in attesa"): la policy profiles_select gia' consente id = auth.uid().

-- Fine migrazione v12.
