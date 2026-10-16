-- =====================================================================
--  Migrazione v171 — Operatore ASSEGNATO alle fasi + sostituzioni
--  - assegnato_*      : chi deve fare la lavorazione (dal preventivo, modificabile in commessa)
--  - assegnato_prev_* : l'operatore previsto nel PREVENTIVO (fisso, per il confronto)
--  - costo_orario_prev: costo orario usato nel preventivo (per segnalare la differenza di costo)
--  - sostituzioni     : quando un altro operatore prende la lavorazione dalla Postazione,
--                       [{da_id,da_nome,a_id,a_nome,motivo,il}] con motivazione obbligatoria
--  Additiva: nessun dato esistente viene toccato.
-- =====================================================================

alter table public.commesse_fasi add column if not exists assegnato_id       uuid;
alter table public.commesse_fasi add column if not exists assegnato_nome     text default '';
alter table public.commesse_fasi add column if not exists assegnato_prev_id  uuid;
alter table public.commesse_fasi add column if not exists assegnato_prev_nome text default '';
alter table public.commesse_fasi add column if not exists costo_orario_prev  numeric;
alter table public.commesse_fasi add column if not exists sostituzioni       jsonb not null default '[]'::jsonb;

-- Recupero per le commesse GIÀ esistenti: se la fase ha un solo operatore (arrivato dal
-- preventivo) e nessun assegnato, lo considero l'assegnato/previsto.
update public.commesse_fasi f
   set assegnato_id      = (f.operatori->0->>'id')::uuid,
       assegnato_nome    = coalesce(f.operatori->0->>'nome',''),
       assegnato_prev_id = (f.operatori->0->>'id')::uuid,
       assegnato_prev_nome = coalesce(f.operatori->0->>'nome','')
 where f.assegnato_id is null
   and jsonb_typeof(f.operatori) = 'array'
   and jsonb_array_length(f.operatori) = 1
   and coalesce(f.operatori->0->>'id','') ~ '^[0-9a-fA-F-]{36}$';

-- Fine migrazione v171.
