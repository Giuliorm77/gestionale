-- =====================================================================
--  MIGRAZIONE v96 - DDT / DOCUMENTI DI TRASPORTO
--
--  Documento di trasporto (delivery note): nasce da una commessa o a mano,
--  con mittente (azienda), destinatario (cliente + sede consegna), dati del
--  trasporto (causale, aspetto beni, colli, peso, vettore, porto) e le righe
--  articoli SENZA prezzi. Numerazione progressiva DDT-AAAA-NNNN.
--
--  RLS: amministratore + commerciale + magazzino (chi spedisce).
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.ddt (
  id            uuid primary key default gen_random_uuid(),
  numero        text unique,                       -- DDT-AAAA-NNNN
  data          date not null default current_date,
  ora_trasporto text default '',                   -- HH:MM
  commessa_id   uuid references public.commesse (id),
  cliente_id    uuid references public.clienti (id),
  cliente_nome  text default '',
  destinatario  jsonb default '{}'::jsonb,          -- snapshot sede consegna
  causale       text default 'Vendita',
  aspetto_beni  text default '',                    -- colli / scatole / pallet…
  colli         int default 0,
  peso_kg       numeric(12,2),
  porto         text default 'Franco',              -- Franco / Assegnato
  vettore_tipo  text default 'mittente',            -- mittente / destinatario / vettore
  vettore_nome  text default '',
  trasporto_a_cura text default '',                 -- note vettore/mezzo
  note          text default '',
  stato         text not null default 'bozza'
                check (stato in ('bozza','emesso','annullato')),
  creato_da     uuid,
  creato_il     timestamptz not null default now()
);
create index if not exists ddt_data_idx     on public.ddt (data desc);
create index if not exists ddt_commessa_idx on public.ddt (commessa_id);

create table if not exists public.ddt_righe (
  id          uuid primary key default gen_random_uuid(),
  ddt_id      uuid not null references public.ddt (id) on delete cascade,
  ordine      int default 0,
  descrizione text not null default '',
  articolo_id uuid references public.articoli (id),
  quantita    numeric(12,2) not null default 1,
  unita       text default ''
);
create index if not exists ddt_righe_ddt_idx on public.ddt_righe (ddt_id);

alter table public.ddt       enable row level security;
alter table public.ddt_righe enable row level security;

drop policy if exists ddt_all on public.ddt;
create policy ddt_all on public.ddt for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','magazzino'));

drop policy if exists ddt_righe_all on public.ddt_righe;
create policy ddt_righe_all on public.ddt_righe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','magazzino'));

-- ---------------------------------------------------------------------
--  VISTA azienda_info: solo l'ANAGRAFICA azienda + carta intestata (mittente
--  del DDT), leggibile da tutti gli utenti approvati (incl. magazzino) SENZA
--  esporre i dati economici di `impostazioni` (spese generali, margini...).
-- ---------------------------------------------------------------------
create or replace view public.azienda_info as
select azienda_nome, azienda_indirizzo, azienda_citta, azienda_piva,
       azienda_email, azienda_tel, azienda_iban,
       carta_intestata, carta_margine_top, carta_margine_bottom, carta_margine_lati,
       condizioni_default
from public.impostazioni
where public.ruolo_utente() is not null;

grant select on public.azienda_info to authenticated;

-- Fine migrazione v96 (DDT / documenti di trasporto).
