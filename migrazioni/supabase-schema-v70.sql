-- =====================================================================
--  MIGRAZIONE v70 - FORNITORI: MATERIALE vs TERZISTA + MATERIE PRIME
--
--  I fornitori sono di due nature diverse:
--   - MATERIALE: ci VENDONO materie prime (forex, pvc, inchiostri, gadget...)
--   - TERZISTA : ci FANNO una lavorazione (fustellatura, taglio polistirolo...)
--   - ENTRAMBI : tutte e due.
--  Il campo "cosa_fornisce" (lavorazioni) resta per i terzisti; per i
--  materiali si usa una nuova lista gestibile "materie_prime" e la colonna
--  "materiali_forniti" sul fornitore.
--
--  Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire.
-- =====================================================================

-- 1) Tipo del fornitore e materiali forniti
alter table public.fornitori add column if not exists tipo text default 'materiale';
alter table public.fornitori add column if not exists materiali_forniti text[] not null default '{}';

-- vincolo sui valori ammessi (idempotente)
do $$ begin
  alter table public.fornitori
    add constraint fornitori_tipo_chk check (tipo in ('materiale','terzista','entrambi'));
exception when duplicate_object then null; end $$;

-- 2) Lista gestibile delle materie prime (categorie di acquisto)
create table if not exists public.materie_prime (
  id        uuid primary key default gen_random_uuid(),
  nome      text not null unique,
  attivo    boolean not null default true,
  ordine    int default 0,
  creato_il timestamptz not null default now()
);

alter table public.materie_prime enable row level security;

-- Lettura: tutti gli utenti approvati (serve nel menu del fornitore)
drop policy if exists materie_prime_select on public.materie_prime;
create policy materie_prime_select on public.materie_prime for select to authenticated
  using (public.ruolo_utente() is not null);

-- Modifica: amministratore e commerciale (come le lavorazioni)
drop policy if exists materie_prime_write on public.materie_prime;
create policy materie_prime_write on public.materie_prime for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Qualche voce di partenza (solo se non gia' presenti)
insert into public.materie_prime (nome, ordine) values
  ('Forex bianco',1),
  ('Forex colorato',2),
  ('PVC',3),
  ('Plexiglass',4),
  ('Cartone / cartotecnica',5),
  ('Polistirolo',6),
  ('Inchiostri',7),
  ('Supporti stampa (banner, carta, vinile)',8),
  ('Imballaggio (pluriball, scatole, nastro)',9),
  ('Gadget',10)
on conflict (nome) do nothing;

-- Fine migrazione v70.
