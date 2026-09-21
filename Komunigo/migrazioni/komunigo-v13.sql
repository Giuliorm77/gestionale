-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v13  (dati di fatturazione sull'account cliente)
--
--  Aggiunge a komunigo_account i dati necessari per emettere fattura:
--  tipo (privato/azienda), ragione sociale, P.IVA, codice fiscale, PEC,
--  codice destinatario SDI, sede legale (indirizzo/CAP/città/provincia) e
--  indirizzo di consegna (se diverso). Tutto ADDITIVO.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.komunigo_account
  add column if not exists tipo_cliente   text not null default 'privato',
  add column if not exists ragione_sociale text not null default '',
  add column if not exists partita_iva     text not null default '',
  add column if not exists codice_fiscale  text not null default '',
  add column if not exists pec             text not null default '',
  add column if not exists codice_sdi      text not null default '',
  add column if not exists cap             text not null default '',
  add column if not exists citta           text not null default '',
  add column if not exists provincia       text not null default '',
  add column if not exists consegna_uguale     boolean not null default true,
  add column if not exists consegna_indirizzo  text not null default '',
  add column if not exists consegna_cap         text not null default '',
  add column if not exists consegna_citta        text not null default '',
  add column if not exists consegna_provincia    text not null default '';

do $$ begin
  if not exists (select 1 from pg_constraint where conname='komunigo_account_tipo_chk') then
    alter table public.komunigo_account
      add constraint komunigo_account_tipo_chk check (tipo_cliente in ('privato','azienda'));
  end if;
end $$;

-- Fine migrazione Komunigo v13.
