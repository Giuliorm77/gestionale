-- =====================================================================
--  MIGRAZIONE v85 - CRM: provvigione a MARGINE su prezzo netto (per trattativa)
--
--  Finora la provvigione dell'agente era solo "a percentuale sul valore"
--  (agenti.provvigione_pct / clienti.provvigione_pct). Ora si aggiunge, a
--  livello di SINGOLA TRATTATIVA, la possibilita' di calcolarla a MARGINE:
--    margine = valore_stimato (prezzo di vendita) - prezzo_netto (quanto
--              vuole incassare l'azienda)
--    provvigione = margine * quota_margine_pct/100  (es. 50% o 100% "tutto a lui")
--
--  Tutto per-trattativa: tipo, netto e quota si scelgono lavoro per lavoro.
--  I campi sono NULL sulle trattative esistenti -> si comportano come prima
--  (tipo_provvigione default 'percentuale').
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.crm_trattative
  add column if not exists tipo_provvigione  text default 'percentuale',
  add column if not exists prezzo_netto       numeric(12,2),
  add column if not exists quota_margine_pct  numeric,
  add column if not exists provvigione_pct    numeric;   -- override % per la singola trattativa (modo percentuale)

-- vincolo sul tipo (idempotente)
alter table public.crm_trattative drop constraint if exists crm_tratt_tipoprovv_check;
alter table public.crm_trattative
  add constraint crm_tratt_tipoprovv_check
  check (tipo_provvigione in ('percentuale','margine'));

-- Fine migrazione v85.
