-- =====================================================================
--  RESET DATI DI TEST — ripartenza pulita (rivedere PRIMA di lanciare!)
--  Azzera: preventivi, commesse, CRM, ordini fornitore, DDT, interventi,
--          scadenze e TUTTE le anagrafiche (clienti/fornitori) — test e non.
--  TIENE:  catalogo articoli, tariffe/lavorazioni, operatori, impostazioni,
--          imballi, agenti, corrieri, mezzi, prodotti, utenti, e il MAGAZZINO
--          (movimenti e pezzi: i pezzi vengono solo scollegati dalle commesse).
--  Dopo il reset: ri-lanciare l'import anagrafiche da Fatture in Cloud e la
--  sincronizzazione dello Scadenzario.
--  È tutto in UNA transazione: se qualcosa va storto, NON cancella nulla.
-- =====================================================================
begin;

-- TENIAMO i pezzi di magazzino: scolleghiamoli dalle commesse che stiamo per cancellare
update public.magazzino_pezzi set commessa_id = null where commessa_id is not null;

-- DDT
delete from public.ddt_righe;
delete from public.ddt;

-- Ordini fornitore
delete from public.ordini_fornitore_righe;
delete from public.ordini_fornitore;

-- Rilavorazioni / interventi post-vendita
do $$ begin delete from public.interventi_righe; exception when undefined_table then null; end $$;
do $$ begin delete from public.interventi;        exception when undefined_table then null; end $$;

-- Impegni materiale (derivati dalle commesse) — opzionale
do $$ begin delete from public.impegni; exception when undefined_table then null; end $$;

-- Commesse
delete from public.commesse_modifiche;
delete from public.commesse_fasi;
delete from public.commesse_righe;
delete from public.commesse;

-- Preventivi
delete from public.preventivi_righe;
delete from public.preventivi;

-- CRM / agenda (nomi opzionali: ignora se non esistono)
do $$ begin delete from public.crm_promemoria; exception when undefined_table then null; end $$;
do $$ begin delete from public.crm_agenda;     exception when undefined_table then null; end $$;
do $$ begin delete from public.agenda_eventi;  exception when undefined_table then null; end $$;
delete from public.crm_trattative;

-- Scadenzario (si ri-sincronizza da FIC)
delete from public.scadenze;
update public.scadenze_sync set ultimo_sync = null, esito = '', n_clienti = 0, n_fornitori = 0 where id = 1;

-- Anagrafiche CLIENTI (+ tabelle collegate)
do $$ begin delete from public.clienti_sconti;     exception when undefined_table then null; end $$;
do $$ begin delete from public.clienti_listini;    exception when undefined_table then null; end $$;
do $$ begin delete from public.clienti_condizioni; exception when undefined_table then null; end $$;
do $$ begin delete from public.clienti_email;      exception when undefined_table then null; end $$;
do $$ begin delete from public.clienti_sedi;       exception when undefined_table then null; end $$;
delete from public.clienti;

-- Anagrafiche FORNITORI (+ sedi)
do $$ begin delete from public.fornitori_sedi; exception when undefined_table then null; end $$;
delete from public.fornitori;

commit;

-- Allinea le giacenze impegnate (ora senza commesse):
--   select public.ricalcola_impegni();
