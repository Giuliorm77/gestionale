-- =====================================================================
--  MIGRAZIONE v6 - MAGAZZINO (Fase 2)
--  Movimenti carico/scarico/rettifica che aggiornano la giacenza articoli.
--  La giacenza viene aggiornata AUTOMATICAMENTE da un trigger, quindi
--  resta sempre coerente con lo storico dei movimenti.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.movimenti_magazzino (
  id           uuid primary key default gen_random_uuid(),
  articolo_id  uuid not null references public.articoli (id) on delete cascade,
  tipo         text not null check (tipo in ('carico','scarico','rettifica')),
  quantita     numeric(12,2) not null default 0,   -- per rettifica = delta (puo' essere negativo)
  causale      text default '',
  riferimento  text default '',
  note         text default '',
  data         timestamptz not null default now(),
  creato_da    uuid references auth.users (id),
  creato_il    timestamptz not null default now()
);
create index if not exists mov_articolo_idx on public.movimenti_magazzino (articolo_id);
create index if not exists mov_data_idx     on public.movimenti_magazzino (data desc);

-- Trigger: applica il movimento alla giacenza dell'articolo
create or replace function public.applica_movimento()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    update public.articoli
       set giacenza = coalesce(giacenza,0) +
             case NEW.tipo when 'carico' then NEW.quantita
                           when 'scarico' then -NEW.quantita
                           else NEW.quantita end,
           aggiornato_il = now()
     where id = NEW.articolo_id;
  elsif TG_OP = 'DELETE' then
    update public.articoli
       set giacenza = coalesce(giacenza,0) -
             case OLD.tipo when 'carico' then OLD.quantita
                           when 'scarico' then -OLD.quantita
                           else OLD.quantita end,
           aggiornato_il = now()
     where id = OLD.articolo_id;
  end if;
  return null;
end; $$;

drop trigger if exists trg_movimento on public.movimenti_magazzino;
create trigger trg_movimento
  after insert or delete on public.movimenti_magazzino
  for each row execute function public.applica_movimento();

-- RLS: come il catalogo -> amministratore e commerciale
alter table public.movimenti_magazzino enable row level security;

drop policy if exists mov_select on public.movimenti_magazzino;
create policy mov_select on public.movimenti_magazzino for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists mov_write on public.movimenti_magazzino;
create policy mov_write on public.movimenti_magazzino for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v6.
