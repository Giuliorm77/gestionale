-- =====================================================================
--  MIGRAZIONE v47 - POSTAZIONE OPERATORE: cronometro a segmenti
--
--  La "Postazione operatore" (schermata tablet, tattile, senza economici)
--  registra il tempo di lavoro sulle lavorazioni (fasi) con logica a
--  SEGMENTI: ogni tratto sa chi ha lavorato e quanto. Da qui nascono i
--  due tempi: NETTO (somma dei segmenti) e ATTRAVERSAMENTO (dal primo
--  avvio all'ultimo stop). Con le pause motivate.
--
--  1) commesse_fasi.chiave: un id STABILE per la fase. Serve perche' le
--     fasi vengono cancellate e ricreate a ogni salvataggio della commessa
--     (gli id cambiano): la chiave no, cosi' i segmenti restano agganciati.
--  2) segmenti_lavoro: i "tratti" di lavoro cronometrati.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- 1) chiave stabile della fase
alter table public.commesse_fasi add column if not exists chiave text;

-- 2) segmenti di lavoro (il "cartellino" della postazione)
create table if not exists public.segmenti_lavoro (
  id             uuid primary key default gen_random_uuid(),
  commessa_id    uuid references public.commesse (id) on delete cascade,
  fase_chiave    text not null,              -- aggancio stabile alla fase
  fase_descr     text default '',            -- snapshot descrizione (storico)
  reparto        text default '',            -- snapshot reparto (storico)
  operatore_id   uuid,                       -- riferimento operatori (senza FK: la lista puo' cambiare)
  operatore_nome text default '',
  inizio         timestamptz not null default now(),
  fine           timestamptz,                -- null = segmento IN CORSO
  motivo         text,                       -- perche' e' finito: 'pausa' | 'cambio' | 'guasto' | 'fine' (null se in corso)
  creato_il      timestamptz default now()
);
create index if not exists idx_segmenti_fase on public.segmenti_lavoro (commessa_id, fase_chiave);
create index if not exists idx_segmenti_incorso on public.segmenti_lavoro (fine) where fine is null;

-- 3) RLS: qualsiasi utente approvato puo' leggere/scrivere i segmenti.
--    NON e' un dato economico, quindi niente gate puo_economici():
--    la produzione (che non vede i soldi) DEVE poter timbrare.
alter table public.segmenti_lavoro enable row level security;
drop policy if exists segmenti_all on public.segmenti_lavoro;
create policy segmenti_all on public.segmenti_lavoro
  for all to authenticated
  using (public.ruolo_utente() is not null)
  with check (public.ruolo_utente() is not null);

-- 4) Vista "solo nomi" degli operatori: la Postazione deve far scegliere
--    CHI sei, ma la produzione NON deve vedere i costi. Questa vista espone
--    solo id + nome (niente costo_annuo/costo_orario), leggibile da tutti.
create or replace view public.operatori_nomi as
  select id, nome, tipo from public.operatori;
grant select on public.operatori_nomi to authenticated;

-- Fine migrazione v47.
