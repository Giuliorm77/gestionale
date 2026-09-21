-- =====================================================================
--  v99 - Modalità di evasione per riga di commessa (Fase B gadget)
--
--  Ogni riga di commessa può essere evasa in tre modi:
--    'interna'   = la produciamo/stampiamo noi (default)
--    'fornitore' = la fa il fornitore (stampa o prodotto finito)
--    'neutro'    = si manda il prodotto NEUTRO (non personalizzato) al cliente
--  In una commessa con più articoli possono convivere tutte le opzioni.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.commesse_righe
  add column if not exists evasione text not null default 'interna';

do $$ begin
  if not exists (select 1 from pg_constraint where conname='commesse_righe_evasione_chk') then
    alter table public.commesse_righe
      add constraint commesse_righe_evasione_chk check (evasione in ('interna','fornitore','neutro'));
  end if;
end $$;

-- Fine v99.
