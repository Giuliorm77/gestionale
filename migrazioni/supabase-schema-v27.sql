-- =====================================================================
--  MIGRAZIONE v27 - COMMESSE / PRODUZIONE
--  Un preventivo ACCETTATO diventa una commessa (pulsante "Crea commessa").
--  Ogni commessa ha delle FASI (una per reparto/lavorazione) con
--  avanzamento (da fare / in corso / fatto), ore previste e gli operatori
--  che ci lavorano con le ore effettive (salvate come JSON nella fase).
--  Il magazzino verra' collegato in una migrazione successiva.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.commesse (
  id            uuid primary key default gen_random_uuid(),
  numero        text default '',
  preventivo_id uuid references public.preventivi (id) on delete set null,
  cliente_id    uuid references public.clienti (id),
  cliente_nome  text default '',
  riferimento   text default '',
  data_consegna date,
  stato         text not null default 'aperta'
                check (stato in ('aperta','in_produzione','pronta','consegnata','chiusa')),
  priorita      text not null default 'normale'
                check (priorita in ('bassa','normale','alta','urgente')),
  valore        numeric(12,2) default 0,      -- snapshot del totale preventivo
  note          text default '',
  creato_da     uuid references auth.users (id),
  creato_il     timestamptz not null default now(),
  aggiornato_il timestamptz not null default now()
);

create table if not exists public.commesse_fasi (
  id           uuid primary key default gen_random_uuid(),
  commessa_id  uuid not null references public.commesse (id) on delete cascade,
  ordine       int default 0,
  reparto      text default '',              -- la lavorazione / reparto
  descrizione  text default '',
  stato        text not null default 'da_fare'
               check (stato in ('da_fare','in_corso','fatto')),
  ore_previste numeric(12,2) default 0,      -- dal preventivo (manodopera)
  operatori    jsonb default '[]'::jsonb,    -- [{id, nome, ore}] -> ore effettive
  note         text default ''
);
create index if not exists fasi_commessa_idx on public.commesse_fasi (commessa_id);

-- RLS: modulo produttivo -> amministratore, commerciale e produzione
alter table public.commesse       enable row level security;
alter table public.commesse_fasi  enable row level security;

drop policy if exists commesse_all on public.commesse;
create policy commesse_all on public.commesse for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione'));

drop policy if exists commesse_fasi_all on public.commesse_fasi;
create policy commesse_fasi_all on public.commesse_fasi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione'));

-- Fine migrazione v27.
