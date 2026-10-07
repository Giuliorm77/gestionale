-- =====================================================================
--  Migrazione v137 — Prodotti compositi (distinta base / kit)
--  Un prodotto composto da più parti (es. Rollup = struttura + telo + stampa
--  + montaggio). In preventivo lo scegli e si "esplode" nelle righe, con la
--  misura propagata ai componenti che la ereditano (telo, stampa).
--  - misura_mode: 'standard' (taglie fisse, ognuna con la sua struttura) oppure
--    'libera' (inserisci L×H in preventivo).
--  - componenti: [{tipo:'articolo'|'configurato'|'manodopera', ref_id, descrizione,
--                  misura:'eredita'|'fissa', quantita}]
--  - taglie: [{nome, l, h, struttura_articolo_id}]  (solo misura_mode='standard')
--  Additiva e reversibile.
-- =====================================================================

create table if not exists public.prodotti_compositi (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  categoria     text,
  attivo        boolean not null default true,
  misura_mode   text not null default 'standard',
  componenti    jsonb,
  taglie        jsonb,
  creato_il     timestamptz not null default now()
);

alter table public.prodotti_compositi enable row level security;
drop policy if exists compositi_all on public.prodotti_compositi;
create policy compositi_all on public.prodotti_compositi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v137.
-- (Per annullare: drop table public.prodotti_compositi;)
