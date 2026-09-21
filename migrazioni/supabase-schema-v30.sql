-- =====================================================================
--  MIGRAZIONE v30 - Aggancio MAGAZZINO alle commesse (scarico materiali)
--
--  La commessa tiene l'elenco dei MATERIALI da consumare in produzione
--  (colonna JSON "consumi"). Quando si "scarica dal magazzino" l'app crea
--  dei movimenti di SCARICO reali in movimenti_magazzino (che aggiornano la
--  giacenza tramite il trigger gia' esistente) e segna il consumo come
--  scaricato, salvando l'id del movimento per poterlo eventualmente stornare.
--
--  Ogni elemento di "consumi" e':
--    { articolo_id, descrizione, quantita, unita, scaricato, movimento_id }
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse add column if not exists consumi jsonb default '[]'::jsonb;

-- Fine migrazione v30.
