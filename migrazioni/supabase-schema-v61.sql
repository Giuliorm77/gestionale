-- =====================================================================
--  Migrazione v61 — CHI HA APERTO LA COMMESSA / CHI CI HA LAVORATO
--
--  Nessun nuovo tracciamento: i dati ci sono gia'.
--    - chi ha aperto  -> commesse.creato_da (salvato dalla v27, mai mostrato)
--    - chi ha lavorato-> segmenti_lavoro (riempita dalla Postazione)
--  Qui si aggiungono solo due VISTE per poterli leggere senza aprire
--  permessi che oggi sono chiusi.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1) Nomi degli utenti del gestionale.
--     profiles e' leggibile SOLO dall'amministratore (e da se stessi):
--     giusto, perche' contiene ruolo, permessi e stato di approvazione.
--     Ma per scrivere "Aperta da Cristina" serve il nome anche a chi
--     amministratore non e'. Questa vista espone SOLO id + nome:
--     niente ruolo, niente permessi, niente approvato.
--     Stesso principio della vista operatori_nomi della v47.
-- ---------------------------------------------------------------------
create or replace view public.profili_nomi as
  select p.id, p.nome
  from public.profiles p
  where public.ruolo_utente() is not null;   -- solo utenti approvati

grant select on public.profili_nomi to authenticated;

-- ---------------------------------------------------------------------
--  2) Ultimo lavoro registrato su ogni commessa.
--     Serve all'elenco commesse: senza questa vista, per sapere "chi ci ha
--     lavorato per ultimo" l'app dovrebbe scaricare TUTTI i segmenti di
--     TUTTE le commesse e cercarci dentro nel browser — lo stesso errore
--     che ci ha nascosto meta' catalogo.
--     distinct on = una riga sola per commessa, la piu' recente.
-- ---------------------------------------------------------------------
create or replace view public.commesse_ultimo_lavoro as
  select distinct on (s.commessa_id)
         s.commessa_id,
         s.operatore_nome,
         s.reparto,
         s.inizio,
         s.fine,
         (s.fine is null) as in_corso
  from public.segmenti_lavoro s
  where s.commessa_id is not null
  order by s.commessa_id, s.inizio desc;

grant select on public.commesse_ultimo_lavoro to authenticated;

-- Indice: l'ordinamento per commessa + data lo fa su ogni caricamento
-- dell'elenco commesse.
create index if not exists segmenti_commessa_inizio_idx
  on public.segmenti_lavoro (commessa_id, inizio desc);

-- Fine migrazione v61.
