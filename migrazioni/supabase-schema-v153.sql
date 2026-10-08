-- =====================================================================
--  Migrazione v153 — Scheda Consuntivi (snapshot congelato del margine)
--  Alla CHIUSURA della commessa (o con il pulsante "Salva consuntivo") viene
--  salvata una fotografia del consuntivo reale (ricavi/costi/margine + voci),
--  che NON cambia più anche se dopo variano costi a catalogo o orari.
--  Una riga per commessa (upsert).
-- =====================================================================

create table if not exists public.commesse_consuntivi (
  id             uuid primary key default gen_random_uuid(),
  commessa_id    uuid not null unique references public.commesse (id) on delete cascade,
  numero         text default '',
  cliente_nome   text default '',
  stato          text default '',
  data_chiusura  date,
  ricavi              numeric(12,2) default 0,
  costo_materiali     numeric(12,2) default 0,
  costo_manodopera    numeric(12,2) default 0,
  trasporto           numeric(12,2) default 0,
  costo_esterno       numeric(12,2) default 0,
  costo_straordinario numeric(12,2) default 0,
  costo_aiuti         numeric(12,2) default 0,
  costo_perdite       numeric(12,2) default 0,
  costo_interventi    numeric(12,2) default 0,
  costo_extra         numeric(12,2) default 0,
  costi_totali        numeric(12,2) default 0,
  margine             numeric(12,2) default 0,
  margine_pct         numeric(6,2)  default 0,
  creato_da      uuid,
  aggiornato_il  timestamptz not null default now()
);

alter table public.commesse_consuntivi enable row level security;
drop policy if exists cons_econ on public.commesse_consuntivi;
create policy cons_econ on public.commesse_consuntivi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v153.
