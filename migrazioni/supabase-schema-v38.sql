-- =====================================================================
--  MIGRAZIONE v38 - Modalità di consegna per articolo (commessa)
--
--  Ogni articolo della commessa può essere consegnato in modo diverso:
--    'corriere'       -> entra nel calcolo del listino corriere (peso/colli)
--    'ritiro_cliente' -> lo ritira il cliente (nessun trasporto)
--    'mezzo_nostro'   -> consegna col nostro mezzo (costo a mano nel calcolatore)
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_righe add column if not exists modalita_consegna text default 'corriere';
-- vincolo sui valori ammessi (idempotente)
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'commesse_righe_modalita_consegna_chk') then
    alter table public.commesse_righe
      add constraint commesse_righe_modalita_consegna_chk
      check (modalita_consegna in ('corriere','ritiro_cliente','mezzo_nostro'));
  end if;
end $$;

-- Fine migrazione v38.
