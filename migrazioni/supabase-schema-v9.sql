-- =====================================================================
--  MIGRAZIONE v9 - Operatori su PIU' reparti
--  Il singolo campo "reparto" diventa un elenco "reparti".
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.operatori add column if not exists reparti text[] not null default '{}';

-- Porta l'eventuale reparto singolo gia' inserito dentro il nuovo elenco
update public.operatori
   set reparti = array[reparto]
 where (reparti is null or array_length(reparti,1) is null)
   and coalesce(reparto,'') <> '';

-- Fine migrazione v9.  (la vecchia colonna "reparto" resta ma non e' piu' usata)
