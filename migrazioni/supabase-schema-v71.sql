-- =====================================================================
--  MIGRAZIONE v71 - BLINDATURA COSTI DI STRUTTURA (solo amministratore)
--
--  I costi di struttura (stipendi indiretti, affitto, fatturato...) erano
--  colonne della tabella "impostazioni", leggibile da amministratore E
--  commerciale. Il commerciale non ne ha bisogno: qui li spostiamo in una
--  tabella separata "impostazioni_struttura" leggibile/scrivibile SOLO
--  dall'amministratore, e li rimuoviamo da "impostazioni".
--
--  Cosi' nemmeno via API un non-amministratore puo' leggerli.
--  I parametri generali (spese generali %, IVA, margine, sconto rivenditori)
--  restano su "impostazioni" e continuano a servire al commerciale.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- 1) Tabella blindata (una sola riga, id=1)
create table if not exists public.impostazioni_struttura (
  id                  int primary key default 1,
  costi_struttura     jsonb   not null default '[]'::jsonb,   -- [{categoria, descrizione, importo, misto, costo_annuo, ore_produzione, costo_orario}]
  costi_diretti_annui numeric default 0,
  fatturato_annuo     numeric default 0,
  aggiornato_il       timestamptz not null default now(),
  constraint impostazioni_struttura_una_riga check (id = 1)
);

alter table public.impostazioni_struttura enable row level security;

-- Lettura/scrittura: SOLO amministratore
drop policy if exists imp_struttura_admin on public.impostazioni_struttura;
create policy imp_struttura_admin on public.impostazioni_struttura for all to authenticated
  using (public.ruolo_utente() = 'amministratore')
  with check (public.ruolo_utente() = 'amministratore');

-- 2) Copia i dati esistenti da "impostazioni" (solo se le vecchie colonne esistono ancora)
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='impostazioni' and column_name='costi_struttura') then
    insert into public.impostazioni_struttura (id, costi_struttura, costi_diretti_annui, fatturato_annuo)
    select 1,
           coalesce(costi_struttura, '[]'::jsonb),
           coalesce(costi_diretti_annui, 0),
           coalesce(fatturato_annuo, 0)
    from public.impostazioni where id = 1
    on conflict (id) do nothing;
  end if;
end $$;

-- garantisce comunque l'esistenza della riga
insert into public.impostazioni_struttura (id) values (1) on conflict (id) do nothing;

-- 3) Rimuovi le colonne sensibili da "impostazioni" (ora vivono nella tabella blindata)
alter table public.impostazioni drop column if exists costi_struttura;
alter table public.impostazioni drop column if exists costi_diretti_annui;
alter table public.impostazioni drop column if exists fatturato_annuo;

-- Fine migrazione v71.
