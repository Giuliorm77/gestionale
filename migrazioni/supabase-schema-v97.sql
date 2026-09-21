-- =====================================================================
--  MIGRAZIONE v97 - DDT da commessa: spedizioni PARZIALI
--
--  Per generare il DDT dagli articoli PRONTI di una commessa, tracciando
--  quanto è già stato spedito (consegne a scaglioni):
--   - commesse_righe.quantita_consegnata: quanto di quella riga è già uscito;
--     quando raggiunge la quantità, la riga passa a 'consegnato'.
--   - ddt_righe.commessa_riga_id: collega la riga del DDT alla riga di commessa,
--     così all'emissione si aggiorna la commessa.
--
--  Additiva. Richiede v96. Da eseguire in Supabase -> SQL Editor -> Run.
-- =====================================================================

alter table public.commesse_righe
  add column if not exists quantita_consegnata numeric(12,2) not null default 0;

alter table public.ddt_righe
  add column if not exists commessa_riga_id uuid references public.commesse_righe (id);

-- Fine migrazione v97.
