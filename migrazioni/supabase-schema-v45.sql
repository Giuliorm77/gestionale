-- =====================================================================
--  MIGRAZIONE v45 - Aiuti imprevisti in produzione (sulla commessa)
--
--  Quando un impiegato (o chiunque) viene chiamato al volo ad aiutare in
--  produzione, si registra qui: operatore + ore + data + nota. Diventa un
--  COSTO IMPREVISTO nel consuntivo (ore × costo orario) e alimenta il Report
--  "Aiuti imprevisti".
--
--  Ogni elemento di "aiuti" e': { operatore_id, nome, ore, data, nota }
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse add column if not exists aiuti jsonb default '[]'::jsonb;

-- Fine migrazione v45.
