-- =====================================================================
--  MIGRAZIONE v80 - CRM rete agenti (FASE 1: modello dati)
--
--  Estende il gestionale a CRM per gli agenti:
--   - collega il login (profiles) a un record agente
--   - pipeline trattative (crm_trattative)
--   - attivita' / follow-up / agenda (crm_attivita)
--
--  Solo tabelle/colonne/indici/trigger. La RLS (isolamento per agente)
--  arriva nella FASE 4 (migrazione separata), dopo aver messo ruoli e UI.
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

-- 1) Collega un profilo (login) a un agente
alter table public.profiles add column if not exists agente_id uuid references public.agenti(id) on delete set null;
create index if not exists idx_profiles_agente on public.profiles(agente_id);
create index if not exists idx_clienti_agente  on public.clienti(agente_id);

-- 2) Trattative (pipeline di vendita)
create table if not exists public.crm_trattative (
  id                uuid primary key default gen_random_uuid(),
  cliente_id        uuid references public.clienti(id) on delete set null,
  agente_id         uuid references public.agenti(id),
  titolo            text not null,
  descrizione       text,
  valore_stimato    numeric(12,2) default 0,
  probabilita       int default 0,                 -- 0..100
  stato             text not null default 'nuovo'  -- nuovo | contatto | trattativa | offerta | vinta | persa
                    check (stato in ('nuovo','contatto','trattativa','offerta','vinta','persa')),
  data_prevista     date,
  motivo_perdita    text,
  preventivo_id     uuid references public.preventivi(id) on delete set null,
  creato_da         uuid references public.profiles(id),
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now()
);
create index if not exists idx_tratt_agente  on public.crm_trattative(agente_id);
create index if not exists idx_tratt_cliente on public.crm_trattative(cliente_id);
create index if not exists idx_tratt_stato   on public.crm_trattative(stato);

-- 3) Attivita' e follow-up (storico contatti + agenda)
create table if not exists public.crm_attivita (
  id             uuid primary key default gen_random_uuid(),
  tipo           text not null default 'nota'      -- chiamata | visita | email | nota | appuntamento
                 check (tipo in ('chiamata','visita','email','nota','appuntamento')),
  cliente_id     uuid references public.clienti(id) on delete cascade,
  trattativa_id  uuid references public.crm_trattative(id) on delete cascade,
  agente_id      uuid references public.agenti(id),
  data_ora       timestamptz not null default now(),
  esito          text,
  note           text,
  completata     boolean not null default true,    -- false = pianificata/da fare
  promemoria_il  timestamptz,                       -- se valorizzato => compare in Agenda
  creato_da      uuid references public.profiles(id),
  creato_il      timestamptz not null default now()
);
create index if not exists idx_att_agente     on public.crm_attivita(agente_id);
create index if not exists idx_att_cliente    on public.crm_attivita(cliente_id);
create index if not exists idx_att_promemoria on public.crm_attivita(promemoria_il) where completata = false;

-- 4) Trigger aggiornato_il sulle trattative
create or replace function public.set_aggiornato_il() returns trigger
language plpgsql as $$ begin new.aggiornato_il = now(); return new; end; $$;

drop trigger if exists trg_tratt_upd on public.crm_trattative;
create trigger trg_tratt_upd before update on public.crm_trattative
  for each row execute function public.set_aggiornato_il();

-- Fine migrazione v80.
