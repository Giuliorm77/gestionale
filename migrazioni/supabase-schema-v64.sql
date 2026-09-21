-- =====================================================================
--  MIGRAZIONE v64 - IMPORT che AGGIORNA, con backup e ripristino
--
--  Finora l'import del catalogo faceva solo INSERT: reimportare lo stesso
--  file creava doppioni e non c'era modo di correggere in blocco.
--
--  Da qui l'import puo' anche AGGIORNARE gli articoli gia' presenti,
--  riconoscendoli dal `codice`. Siccome e' un'operazione di massa che
--  tocca dati veri, ogni import salva PRIMA una copia delle righe che
--  sta per cambiare, e si puo' annullare.
--
--  Scelte concordate:
--   - riconoscimento per `codice` (quello parlante: MAT-FOREX-03-BN)
--   - codice presente piu' volte in catalogo -> SALTA e segnala
--   - aggiornamento in blocco riservato all'AMMINISTRATORE
--   - le celle vuote non toccano nulla (lato app)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Un record per ogni import eseguito
-- ---------------------------------------------------------------------
create table if not exists public.import_batch (
  id            uuid primary key default gen_random_uuid(),
  file_nome     text default '',
  n_inseriti    int  default 0,
  n_aggiornati  int  default 0,
  annullato_il  timestamptz,
  creato_il     timestamptz default now(),
  creato_da     uuid
);

-- ---------------------------------------------------------------------
-- 2. Copia di sicurezza delle righe toccate
--    azione='update' -> dati_prima = la riga COMPLETA com'era (per rimetterla)
--    azione='insert' -> la riga non esisteva: per annullare va cancellata
-- ---------------------------------------------------------------------
create table if not exists public.import_backup (
  id          uuid primary key default gen_random_uuid(),
  batch_id    uuid not null references public.import_batch (id) on delete cascade,
  articolo_id uuid not null,
  azione      text not null check (azione in ('insert','update')),
  dati_prima  jsonb
);
create index if not exists import_backup_batch_idx on public.import_backup (batch_id);

-- ---------------------------------------------------------------------
-- 3. Permessi: solo l'amministratore. Sono dati di servizio, e l'annullamento
--    riscrive il catalogo: non va lasciato a tutti.
-- ---------------------------------------------------------------------
alter table public.import_batch  enable row level security;
alter table public.import_backup enable row level security;

drop policy if exists import_batch_admin on public.import_batch;
create policy import_batch_admin on public.import_batch for all to authenticated
  using (public.ruolo_utente() = 'amministratore')
  with check (public.ruolo_utente() = 'amministratore');

drop policy if exists import_backup_admin on public.import_backup;
create policy import_backup_admin on public.import_backup for all to authenticated
  using (public.ruolo_utente() = 'amministratore')
  with check (public.ruolo_utente() = 'amministratore');

-- Fine migrazione v64.
