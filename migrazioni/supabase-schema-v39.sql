-- =====================================================================
--  MIGRAZIONE v39 - Modalità di consegna per riga anche nel PREVENTIVO
--  Il cliente la conosce a priori (compare sul PDF). Alla creazione della
--  commessa viene ereditata (poi modificabile in produzione).
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.preventivi_righe add column if not exists modalita_consegna text default 'corriere';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'preventivi_righe_modalita_consegna_chk') then
    alter table public.preventivi_righe
      add constraint preventivi_righe_modalita_consegna_chk
      check (modalita_consegna in ('corriere','ritiro_cliente','mezzo_nostro'));
  end if;
end $$;

-- Fine migrazione v39.
