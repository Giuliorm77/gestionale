-- =====================================================================
--  MIGRAZIONE v48 - RUOLO "MAGAZZINO" (magazziniere/spedizioni SENZA dati economici)
--
--  Obiettivo: dare a un magazziniere dedicato l'accesso a carico/scarico e
--  alle commesse (lato operativo), SENZA mai mostrargli costi/prezzi.
--
--  Nodo tecnico: la RLS di Postgres nasconde le RIGHE, non le COLONNE, e la
--  tabella `articoli` tiene giacenza e costi insieme. Quindi NON diamo al ruolo
--  magazzino la tabella `articoli` (esporrebbe `costo`), ma una VISTA senza soldi.
--
--  Tutto ADDITIVO: allarga le policy per includere il ruolo 'magazzino'
--  (che oggi non ha nessun utente) -> non cambia nulla per admin/commerciale/produzione.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. VISTA ARTICOLI SENZA PREZZI (per il modulo Magazzino, tutti i ruoli operativi)
--    Espone solo l'identificazione + la giacenza. MAI costo/prezzi.
--    La vista (owner postgres) bypassa la RLS di `articoli` ma mostra solo la
--    proiezione sicura; il filtro sui ruoli evita che la veda chi non deve.
-- ---------------------------------------------------------------------
drop view if exists public.articoli_magazzino;
create view public.articoli_magazzino as
select
  a.id, a.codice, a.nome_articolo, a.unita, a.tipo,
  a.giacenza, a.impegnato, a.scorta_minima
from public.articoli a
where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione');

grant select on public.articoli_magazzino to authenticated;
comment on view public.articoli_magazzino is
  'Vista articoli senza dati economici: usata dal modulo Magazzino (incl. ruolo magazzino).';

-- ---------------------------------------------------------------------
-- 2. MOVIMENTI DI MAGAZZINO: aggiungo il ruolo 'magazzino' (ricreo le policy v6)
-- ---------------------------------------------------------------------
drop policy if exists mov_select on public.movimenti_magazzino;
create policy mov_select on public.movimenti_magazzino for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','magazzino'));

drop policy if exists mov_write on public.movimenti_magazzino;
create policy mov_write on public.movimenti_magazzino for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','magazzino'));

-- ---------------------------------------------------------------------
-- 3. COMMESSE (testata, fasi, righe): aggiungo 'magazzino' come per 'produzione'
--    Serve al magazzino per vedere cosa spedire e segnare pronto/consegnato.
--    (La creazione/eliminazione commessa resta comunque bloccata dalla UI.)
-- ---------------------------------------------------------------------
drop policy if exists commesse_all on public.commesse;
create policy commesse_all on public.commesse for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

drop policy if exists commesse_fasi_all on public.commesse_fasi;
create policy commesse_fasi_all on public.commesse_fasi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

drop policy if exists commesse_righe_all on public.commesse_righe;
create policy commesse_righe_all on public.commesse_righe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));

-- Nota: `articoli` NON viene toccata: il ruolo magazzino NON legge la tabella
-- (vedrebbe i costi), usa solo la vista articoli_magazzino qui sopra.

-- Fine migrazione v48.
