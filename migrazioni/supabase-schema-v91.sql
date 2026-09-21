-- =====================================================================
--  MIGRAZIONE v91 - Mezzi/Strumenti: frequenza con UNITA' (giorni/settimane/mesi/anni)
--
--  Finora la frequenza era solo in mesi (frequenza_mesi). Alcune macchine
--  vanno controllate ogni giorno/settimana: aggiungiamo valore + unità.
--  Migriamo i dati esistenti (frequenza_mesi -> valore, unità 'mesi').
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.strumenti
  add column if not exists frequenza_valore int,
  add column if not exists frequenza_unita  text default 'mesi';

alter table public.strumenti drop constraint if exists strumenti_frequnita_check;
alter table public.strumenti
  add constraint strumenti_frequnita_check
  check (frequenza_unita in ('giorni','settimane','mesi','anni'));

-- porta i valori esistenti (in mesi) nel nuovo schema
update public.strumenti
   set frequenza_valore = coalesce(frequenza_valore, frequenza_mesi),
       frequenza_unita  = coalesce(frequenza_unita, 'mesi')
 where frequenza_valore is null;

-- Fine migrazione v91.
