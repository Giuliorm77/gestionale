-- =====================================================================
--  MIGRAZIONE v62 - IMBALLO consigliato per modalita' di consegna
--
--  Un pannello spedito col CORRIERE va protetto (pluriball, angolari,
--  parabordi); lo stesso pannello consegnato col NOSTRO MEZZO puo' bastare
--  con l'estensibile. Sono due "ricette" di imballo diverse.
--
--  Finora imballo e modalita' di consegna erano due scelte indipendenti:
--  nessuno avvisava se si sceglieva l'imballo leggero per una spedizione
--  a corriere. Questo campo permette di suggerire la ricetta giusta e di
--  segnalare l'incoerenza (resta comunque tutto modificabile a mano).
--
--  Valori: 'corriere' | 'mezzo_nostro' | 'qualsiasi' (default).
--
--  NB: v60 e v61 sono di un'ALTRA sessione (ricerca catalogo lato server /
--      viste chi-ha-aperto-la-commessa): vanno eseguite anche quelle.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.imballi add column if not exists consigliato_per text default 'qualsiasi';

-- Fine migrazione v62.
