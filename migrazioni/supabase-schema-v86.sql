-- =====================================================================
--  MIGRAZIONE v86 - Provvigione decisa dal COMMERCIALE nel PREVENTIVO
--
--  Regola aziendale: NON e' l'agente a decidere come sara' gestita la
--  provvigione, ma il commerciale in fase di preventivo.
--  Quindi i campi provvigione vivono sul PREVENTIVO (modulo riservato a
--  commerciale/amministratore). Al salvataggio, l'app li "ribalta" sulla
--  trattativa CRM collegata (crm_trattative.preventivo_id) che resta la
--  base dei report/KPI gia' esistenti; l'agente la vede in sola lettura.
--
--  Stessi campi introdotti su crm_trattative in v85.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi
  add column if not exists tipo_provvigione  text default 'percentuale',
  add column if not exists prezzo_netto       numeric(12,2),
  add column if not exists quota_margine_pct  numeric,
  add column if not exists provvigione_pct    numeric;

alter table public.preventivi drop constraint if exists preventivi_tipoprovv_check;
alter table public.preventivi
  add constraint preventivi_tipoprovv_check
  check (tipo_provvigione in ('percentuale','margine'));

-- Fine migrazione v86.
