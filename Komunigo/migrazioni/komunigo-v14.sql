-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v14  (B2B Fase 3: pagamento differito + fido)
--  + FIX SICUREZZA sui campi sensibili dell'account cliente.
--
--  COSA FA:
--   1) Aggiunge a komunigo_account i campi del PAGAMENTO DIFFERITO (conto aperto):
--      pagamento_differito (sì/no), fido_massimo (€, il tetto = copertura
--      assicurazione sul credito), giorni_pagamento (30/60...). Li imposta lo STAFF.
--   2) Aggiunge komunigo_ordini.pagamento_giorni (termini "congelati" sull'ordine).
--   3) SICUREZZA: finora la policy self era "for all" -> un cliente poteva
--      aggiornare la PROPRIA riga, incluso stato/cliente_id (e ora il fido),
--      auto-assegnandosi B2B/sconti/credito. Ora il cliente può aggiornare SOLO
--      i dati di fatturazione (grant a livello di colonna); i campi sensibili li
--      cambia solo lo staff tramite la funzione komunigo_account_set_b2b().
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---- 1) campi pagamento differito / fido ----
alter table public.komunigo_account
  add column if not exists pagamento_differito boolean not null default false,
  add column if not exists fido_massimo        numeric(12,2) not null default 0,
  add column if not exists giorni_pagamento     int not null default 30;

-- ---- 2) termini di pagamento congelati sull'ordine ----
alter table public.komunigo_ordini
  add column if not exists pagamento_giorni int;

-- ---- 3) SICUREZZA: il cliente aggiorna SOLO i propri dati di fatturazione ----
-- Sostituisco la policy self "for all" con select + update (a livello riga);
-- la restrizione sulle COLONNE la fa il grant qui sotto (RLS non filtra le colonne).
drop policy if exists komunigo_account_self on public.komunigo_account;
create policy komunigo_account_self_sel on public.komunigo_account
  for select to authenticated using (id = auth.uid());
create policy komunigo_account_self_upd on public.komunigo_account
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- niente insert/delete lato client: la riga la crea il trigger handle_new_user (security definer)
revoke insert, delete on public.komunigo_account from authenticated;

-- aggiornabile SOLO le colonne di contatto/fatturazione (né da cliente né da staff via API diretta):
revoke update on public.komunigo_account from authenticated;
grant  update (email, nome, azienda, telefono, indirizzo,
              tipo_cliente, ragione_sociale, partita_iva, codice_fiscale, pec, codice_sdi,
              cap, citta, provincia, consegna_uguale, consegna_indirizzo, consegna_cap,
              consegna_citta, consegna_provincia)
  on public.komunigo_account to authenticated;

-- ---- lo STAFF cambia i campi sensibili solo tramite questa funzione (controlla il ruolo) ----
create or replace function public.komunigo_account_set_b2b(
  p_id uuid,
  p_cliente_id uuid,
  p_stato text,
  p_differito boolean,
  p_fido numeric,
  p_giorni int
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.ruolo_utente() not in ('amministratore','commerciale') then
    raise exception 'Non autorizzato';
  end if;
  update public.komunigo_account set
    cliente_id          = p_cliente_id,
    stato               = coalesce(p_stato, stato),
    pagamento_differito = coalesce(p_differito, pagamento_differito),
    fido_massimo        = coalesce(p_fido, fido_massimo),
    giorni_pagamento    = coalesce(p_giorni, giorni_pagamento)
  where id = p_id;
end $$;

revoke all on function public.komunigo_account_set_b2b(uuid,uuid,text,boolean,numeric,int) from public, anon;
grant execute on function public.komunigo_account_set_b2b(uuid,uuid,text,boolean,numeric,int) to authenticated;

-- Fine migrazione Komunigo v14.
