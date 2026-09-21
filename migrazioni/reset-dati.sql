-- =====================================================================
--  RESET DATI - Azzera TUTTI i dati inseriti per ripartire puliti.
--
--  COSA FA:
--   - Svuota clienti, fornitori (+sedi), catalogo (+listino fornitori, foto ref),
--     magazzino, operatori, listini, prodotti configurabili, imballi,
--     preventivi, COMMESSE (+fasi/righe), ORDINI FORNITORE, CORRIERI,
--     INTERVENTI/rilavorazioni, tariffe.
--   - NON tocca la struttura (tabelle, regole di sicurezza, funzioni).
--   - NON tocca gli UTENTI/login: resti collegato come amministratore.
--   - Ri-crea l'elenco lavorazioni di partenza e la riga Impostazioni.
--
--  NOTA: le FOTO caricate restano nello Storage (bucket "articoli"); non
--  danno problemi, sono solo file orfani. Si possono ripulire a parte.
--
--  ATTENZIONE: e' DEFINITIVO. Se vuoi conservare i dati attuali, lancia
--  prima il backup (backup-gestionale.ps1) o esporta da Supabase.
--
--  Da eseguire in Supabase -> SQL Editor -> Run.
-- =====================================================================

truncate table
  public.interventi_righe, public.interventi,
  public.preventivi_righe, public.preventivi,
  public.commesse_righe, public.commesse_fasi, public.commesse,
  public.ordini_fornitore_righe, public.ordini_fornitore,
  public.corrieri_scaglioni, public.corrieri,
  public.prodotti_config_fasce, public.prodotti_config_voci,
  public.prodotti_config_varianti, public.prodotti_config,
  public.imballi_voci, public.imballi,
  public.movimenti_magazzino,
  public.articoli_fornitori, public.articoli,
  public.clienti_condizioni, public.clienti_listini,
  public.clienti_sedi, public.clienti_email, public.clienti,
  public.fornitori_sedi, public.fornitori,
  public.operatori,
  public.listini_voci, public.listini,
  public.impostazioni_lavorazioni,
  public.impostazioni,
  public.lavorazioni
  restart identity cascade;

-- Ri-crea l'elenco lavorazioni di base (modificabile poi in Impostazioni)
insert into public.lavorazioni (nome, ordine) values
  ('Stampa digitale piccolo formato',1),
  ('Stampa digitale grande formato',2),
  ('Serigrafia',3),
  ('Gadget',4),
  ('Allestimenti eventi',5),
  ('Scenografie polistirolo',6),
  ('Insegne luminose',7),
  ('Cartotecnica',8),
  ('Packaging',9)
on conflict (nome) do nothing;

-- Ri-crea la riga unica delle Impostazioni (valori di default)
insert into public.impostazioni (id) values (1) on conflict do nothing;

-- Fine reset.
