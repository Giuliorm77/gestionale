-- =====================================================================
--  MIGRAZIONE v67 - IMBALLO PER RIGA anche nei PREVENTIVI
--
--  La commessa gia' ha l'imballo per riga (commesse_righe.imballo_id +
--  imballo_costo). Il preventivo no. Qui si allineano le righe preventivo,
--  cosi' si puo' scegliere l'imballo su OGNI riga materiale e il costo
--  viaggia fino alla commessa.
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi_righe add column if not exists imballo_id    uuid references public.imballi (id);
alter table public.preventivi_righe add column if not exists imballo_costo numeric default 0;

-- Fine migrazione v67.
