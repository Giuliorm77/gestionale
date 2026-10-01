-- =====================================================================
--  Migrazione v108 — Destinazione (sede) per riga di PREVENTIVO
--  Permette di assegnare ogni riga del preventivo a una sede del cliente
--  e di stampare un preventivo per singola sede (solo i suoi materiali).
--  La sede si porta poi nella commessa (commesse_righe.sede_id, v104).
--  Additiva e reversibile.
-- =====================================================================

alter table public.preventivi_righe
  add column if not exists sede_id uuid references public.clienti_sedi(id) on delete set null;

create index if not exists idx_prevrighe_sede on public.preventivi_righe(sede_id);

-- Fine migrazione v108.
-- (Per annullare: alter table public.preventivi_righe drop column sede_id;)
