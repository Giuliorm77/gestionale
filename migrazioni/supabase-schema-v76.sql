-- =====================================================================
--  MIGRAZIONE v76 - FIX vincolo stato delle FASI di commessa
--
--  Le fasi ESTERNE (lavorazioni presso terzisti) usano gli stati
--  'da_inviare' | 'inviata' | 'rientrata' (introdotti con la v53), ma il
--  CHECK originale (v27) ammetteva solo 'da_fare' | 'in_corso' | 'fatto'.
--  Risultato: salvando una commessa con una fase esterna il database
--  rifiutava la riga ("commesse_fasi_stato_check").
--
--  Qui allarghiamo il vincolo a TUTTI gli stati validi.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_fasi drop constraint if exists commesse_fasi_stato_check;

alter table public.commesse_fasi
  add constraint commesse_fasi_stato_check
  check (stato in ('da_fare','in_corso','fatto','da_inviare','inviata','rientrata'));

-- Fine migrazione v76.
