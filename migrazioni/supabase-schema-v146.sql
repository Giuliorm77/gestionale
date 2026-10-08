-- =====================================================================
--  Migrazione v146 — Fix indice per l'upsert dello Scadenzario (fic-sync)
--  L'indice unico PARZIALE su fic_payment_id non è utilizzabile da PostgREST
--  per ON CONFLICT (errore 42P10). Lo sostituiamo con uno NON parziale.
--  (I NULL restano distinti in Postgres, quindi i documenti senza rata non
--   violano l'unicità e passano dall'altro ramo di insert.)
-- =====================================================================

drop index if exists public.scad_ficpay_uidx;
create unique index if not exists scad_ficpay_uidx on public.scadenze (fic_payment_id);

-- Fine migrazione v146.
