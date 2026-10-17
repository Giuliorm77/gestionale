-- =====================================================================
--  Migrazione v176 — Corrieri: le TRE misure massime accettate
--  max_lato_cm (v175) diventa la LUNGHEZZA massima; si aggiungono
--  larghezza e altezza. Il controllo non dipende dall'orientamento:
--  misure del pacco e limiti si confrontano ordinati dal più grande.
-- =====================================================================

alter table public.corrieri add column if not exists max_larg_cm numeric;   -- null = nessun limite
alter table public.corrieri add column if not exists max_alt_cm  numeric;   -- null = nessun limite

-- Fine migrazione v176.
