-- =====================================================================
--  Migrazione v104 — Destinazione (sede) per riga di commessa
--  Ordine unico consegnato a più sedi: ogni riga materiale può puntare
--  a una sede del cliente (clienti_sedi). NULL = sede principale.
--  Additiva e reversibile: non tocca nulla di esistente.
-- =====================================================================

alter table public.commesse_righe
  add column if not exists sede_id uuid references public.clienti_sedi(id) on delete set null;

create index if not exists idx_commrighe_sede on public.commesse_righe(sede_id);

-- Fine migrazione v104.
-- (Per annullare: alter table public.commesse_righe drop column sede_id;)
