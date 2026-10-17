-- =====================================================================
--  Migrazione v178 — Trasferte e spese degli allestitori
--  * Nuovo ruolo 'allestitore': vede SOLO le sue trasferte (app dal telefono).
--  * Il Back office apre una TRASFERTA sulla commessa (chi parte, date, budget).
--  * Gli allestitori caricano le SPESE con la foto dello scontrino.
--  * L'amministrazione (amministratore / Back office) APPROVA o rifiuta:
--    solo le approvate entrano negli extra costi della commessa (consuntivo/Report).
--  * Spese pagate con soldi propri → elenco rimborsi.
-- =====================================================================

-- 1) ruolo
alter table public.profiles drop constraint if exists profiles_ruolo_check;
alter table public.profiles add constraint profiles_ruolo_check
  check (ruolo in ('amministratore','commerciale','agente','produzione','magazzino','reception','allestitore'));

-- chi gestisce/approva: amministratore + Back office
create or replace function public.ruolo_economico()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.ruolo_utente() in ('amministratore','commerciale'), false);
$$;
grant execute on function public.ruolo_economico() to authenticated;

-- 2) trasferte
create table if not exists public.trasferte (
  id                uuid primary key default gen_random_uuid(),
  commessa_id       uuid references public.commesse(id) on delete cascade,
  commessa_numero   text default '',          -- copiati: l'allestitore NON legge le commesse
  cliente_nome      text default '',
  titolo            text default '',
  luogo             text default '',
  dal               date,
  al                date,
  budget            numeric(12,2),
  partecipanti      uuid[] not null default '{}',
  partecipanti_nomi text[] not null default '{}',
  stato             text not null default 'aperta' check (stato in ('aperta','chiusa')),
  note              text default '',
  creato_da         uuid,
  creato_il         timestamptz default now(),
  chiusa_il         timestamptz
);
create index if not exists trasferte_commessa_idx on public.trasferte(commessa_id);

alter table public.trasferte enable row level security;
drop policy if exists trasferte_sel on public.trasferte;
drop policy if exists trasferte_gest on public.trasferte;
create policy trasferte_sel on public.trasferte for select to authenticated
  using (public.ruolo_economico() or (public.ruolo_utente() is not null and auth.uid() = any(partecipanti)));
create policy trasferte_gest on public.trasferte for all to authenticated
  using (public.ruolo_economico()) with check (public.ruolo_economico());

-- 3) spese
create table if not exists public.trasferte_spese (
  id                uuid primary key default gen_random_uuid(),
  trasferta_id      uuid not null references public.trasferte(id) on delete cascade,
  commessa_id       uuid,
  utente_id         uuid not null default auth.uid(),
  utente_nome       text default '',
  data              date not null default current_date,
  categoria         text not null default 'altro',
  importo           numeric(12,2) not null check (importo >= 0),
  pagamento         text not null default 'carta' check (pagamento in ('carta','propri')),
  nota              text default '',
  foto_path         text,
  stato             text not null default 'da_approvare' check (stato in ('da_approvare','approvata','rifiutata')),
  motivo_rifiuto    text,
  approvata_da_nome text,
  approvata_il      timestamptz,
  riaddebita        boolean not null default false,
  rimborsata        boolean not null default false,
  rimborsata_il     timestamptz,
  creato_il         timestamptz default now()
);
create index if not exists trasf_spese_trasf_idx on public.trasferte_spese(trasferta_id);
create index if not exists trasf_spese_comm_idx  on public.trasferte_spese(commessa_id);

-- commessa e nome dell'utente presi dal server (non dal telefono)
create or replace function public.trasferte_spese_prepara()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select commessa_id into new.commessa_id from public.trasferte where id = new.trasferta_id;
  if tg_op = 'INSERT' then
    select nome into new.utente_nome from public.profiles where id = new.utente_id;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_trasferte_spese_prepara on public.trasferte_spese;
create trigger trg_trasferte_spese_prepara before insert or update on public.trasferte_spese
  for each row execute function public.trasferte_spese_prepara();

alter table public.trasferte_spese enable row level security;
drop policy if exists tspese_sel on public.trasferte_spese;
drop policy if exists tspese_ins on public.trasferte_spese;
drop policy if exists tspese_upd on public.trasferte_spese;
drop policy if exists tspese_del on public.trasferte_spese;
create policy tspese_sel on public.trasferte_spese for select to authenticated
  using (public.ruolo_economico() or utente_id = auth.uid());
-- l'allestitore inserisce solo spese SUE, da approvare, su una trasferta APERTA dove è partecipante
create policy tspese_ins on public.trasferte_spese for insert to authenticated
  with check (public.ruolo_economico() or (
    utente_id = auth.uid() and stato = 'da_approvare' and rimborsata = false and riaddebita = false
    and exists (select 1 from public.trasferte t where t.id = trasferta_id and t.stato = 'aperta' and auth.uid() = any(t.partecipanti))));
-- finché non è approvata la può correggere/cancellare; dopo solo l'amministrazione
create policy tspese_upd on public.trasferte_spese for update to authenticated
  using (public.ruolo_economico() or (utente_id = auth.uid() and stato = 'da_approvare'))
  with check (public.ruolo_economico() or (utente_id = auth.uid() and stato = 'da_approvare' and rimborsata = false and riaddebita = false));
create policy tspese_del on public.trasferte_spese for delete to authenticated
  using (public.ruolo_economico() or (utente_id = auth.uid() and stato = 'da_approvare'));

-- 4) foto degli scontrini: bucket privato, cartella = id utente
insert into storage.buckets (id, name, public) values ('scontrini','scontrini', false)
on conflict (id) do nothing;
drop policy if exists "scontrini_sel" on storage.objects;
drop policy if exists "scontrini_ins" on storage.objects;
drop policy if exists "scontrini_del" on storage.objects;
create policy "scontrini_sel" on storage.objects for select to authenticated
  using (bucket_id = 'scontrini' and ((storage.foldername(name))[1] = auth.uid()::text or public.ruolo_economico()));
create policy "scontrini_ins" on storage.objects for insert to authenticated
  with check (bucket_id = 'scontrini' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "scontrini_del" on storage.objects for delete to authenticated
  using (bucket_id = 'scontrini' and ((storage.foldername(name))[1] = auth.uid()::text or public.ruolo_economico()));

-- Fine migrazione v178.
