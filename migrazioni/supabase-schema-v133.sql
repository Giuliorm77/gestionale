-- =====================================================================
--  Migrazione v133 — Eliminazione preventivi/commesse: SOLO amministratore
--  Le vecchie policy erano FOR ALL (incluso DELETE) per commerciale
--  (preventivi) e per commerciale/produzione/magazzino (commesse).
--  Qui SELECT/INSERT/UPDATE restano invariati per quei ruoli, ma il
--  DELETE del record viene limitato al solo 'amministratore'.
--  NB: le righe/fasi figlie restano cancellabili dai ruoli operativi:
--  servono al normale SALVATAGGIO (che cancella e reinserisce le righe)
--  e alla cancellazione a cascata quando l'amministratore elimina il padre.
--  Correttiva e reversibile.
-- =====================================================================

-- ---------- PREVENTIVI ----------
drop policy if exists preventivi_all on public.preventivi;
drop policy if exists preventivi_sel on public.preventivi;
drop policy if exists preventivi_ins on public.preventivi;
drop policy if exists preventivi_upd on public.preventivi;
drop policy if exists preventivi_del on public.preventivi;

create policy preventivi_sel on public.preventivi for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));
create policy preventivi_ins on public.preventivi for insert to authenticated
  with check (public.ruolo_utente() in ('amministratore','commerciale'));
create policy preventivi_upd on public.preventivi for update to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));
create policy preventivi_del on public.preventivi for delete to authenticated
  using (public.ruolo_utente() = 'amministratore');

-- ---------- COMMESSE ----------
drop policy if exists commesse_all on public.commesse;
drop policy if exists commesse_sel on public.commesse;
drop policy if exists commesse_ins on public.commesse;
drop policy if exists commesse_upd on public.commesse;
drop policy if exists commesse_del on public.commesse;

create policy commesse_sel on public.commesse for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));
create policy commesse_ins on public.commesse for insert to authenticated
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));
create policy commesse_upd on public.commesse for update to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione','magazzino'));
create policy commesse_del on public.commesse for delete to authenticated
  using (public.ruolo_utente() = 'amministratore');

-- Fine migrazione v133.
-- (Per annullare: ripristinare le policy FOR ALL di v13 (preventivi) e v48 (commesse).)
