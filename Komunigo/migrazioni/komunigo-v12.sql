-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v12  (account clienti B2B - Fase 1)
--
--  COSA FA:
--   1) tabella komunigo_account: i clienti registrati sul negozio (id = auth.uid()).
--      NON danno alcun accesso al gestionale.
--   2) MODIFICA handle_new_user(): se il nuovo utente auth è un cliente Komunigo
--      (metadata komunigo='true') crea un komunigo_account; ALTRIMENTI mantiene il
--      comportamento attuale (profilo staff 'reception'). Così i clienti non
--      diventano utenti del gestionale.
--   3) komunigo_ordini.account_id: collega l'ordine al cliente registrato, con
--      policy "il cliente vede i PROPRI ordini/righe/file".
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---- 1) account clienti ----
create table if not exists public.komunigo_account (
  id         uuid primary key,                 -- = auth.uid()
  email      text,
  nome       text not null default '',
  azienda    text not null default '',
  telefono   text not null default '',
  indirizzo  text not null default '',
  cliente_id uuid references public.clienti (id),   -- collegamento all'anagrafica (B2B), lo imposta lo staff
  stato      text not null default 'nuovo' check (stato in ('nuovo','attivo','b2b','sospeso')),
  creato_il  timestamptz not null default now()
);

alter table public.komunigo_account enable row level security;
-- il cliente legge/aggiorna la PROPRIA riga
drop policy if exists komunigo_account_self on public.komunigo_account;
create policy komunigo_account_self on public.komunigo_account for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- lo staff gestisce tutti gli account (per collegarli a clienti / abilitare B2B)
drop policy if exists komunigo_account_staff on public.komunigo_account;
create policy komunigo_account_staff on public.komunigo_account for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---- 2) trigger: clienti Komunigo NON diventano staff ----
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.raw_user_meta_data->>'komunigo','') = 'true' then
    insert into public.komunigo_account (id, email, nome, azienda, telefono)
    values (new.id, new.email,
      coalesce(new.raw_user_meta_data->>'nome',''),
      coalesce(new.raw_user_meta_data->>'azienda',''),
      coalesce(new.raw_user_meta_data->>'telefono',''))
    on conflict (id) do nothing;
  else
    insert into public.profiles (id, nome, ruolo)
    values (new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)), 'reception')
    on conflict (id) do nothing;
  end if;
  return new;
end $$;

-- ---- 3) ordini legati all'account cliente ----
alter table public.komunigo_ordini add column if not exists account_id uuid;

drop policy if exists komunigo_ordini_self on public.komunigo_ordini;
create policy komunigo_ordini_self on public.komunigo_ordini for select to authenticated
  using (account_id = auth.uid());

drop policy if exists komunigo_righe_self on public.komunigo_ordini_righe;
create policy komunigo_righe_self on public.komunigo_ordini_righe for select to authenticated
  using (exists (select 1 from public.komunigo_ordini o where o.id = ordine_id and o.account_id = auth.uid()));

drop policy if exists komunigo_file_self on public.komunigo_ordini_file;
create policy komunigo_file_self on public.komunigo_ordini_file for select to authenticated
  using (exists (select 1 from public.komunigo_ordini o where o.id = ordine_id and o.account_id = auth.uid()));

-- Fine migrazione Komunigo v12.
