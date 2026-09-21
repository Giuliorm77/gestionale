-- =====================================================================
--  MIGRAZIONE v35 - PESO articoli + LISTINO TRASPORTO (corrieri)
--
--  1) Peso "specifico" sull'articolo: si calcola il peso di una misura/qtà
--     precisa. peso_um dice come scala il peso:
--       'pz'  -> peso_kg = kg per pezzo
--       'mq'  -> peso_kg = kg per m² (per pannelli/lastre: es. 8,33 kg/m²)
--       'mtl' -> peso_kg = kg per metro lineare
--     peso_eccedenza_pct = maggiorazione % (imballo/colla/extra).
--
--  2) Listini trasporto per corriere+zona, a scaglioni su una BASE di calcolo
--     (peso / peso volumetrico / colli / volume / mq). Il calcolatore userà
--     lo scaglione giusto + supplemento a collo + minimo.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- 1) PESO ARTICOLI ---------------------------------------------------------
alter table public.articoli add column if not exists peso_kg            numeric(12,3) default 0;
alter table public.articoli add column if not exists peso_um            text default 'pz';   -- pz | mq | mtl
alter table public.articoli add column if not exists peso_eccedenza_pct numeric default 0;

-- 2) LISTINI TRASPORTO -----------------------------------------------------
create table if not exists public.corrieri (
  id                uuid primary key default gen_random_uuid(),
  nome              text default '',
  zona              text default '',                 -- es. "Italia Nord", "Isole", o range CAP
  base              text not null default 'peso'
                    check (base in ('peso','peso_volumetrico','colli','volume','mq')),
  coeff_volumetrico numeric default 200,             -- kg per m³ (per peso volumetrico)
  supplemento_collo numeric(12,2) default 0,         -- € aggiunti per ogni collo
  minimo            numeric(12,2) default 0,          -- € minimo di spesa
  attivo            boolean default true,
  note              text default ''
);

create table if not exists public.corrieri_scaglioni (
  id          uuid primary key default gen_random_uuid(),
  corriere_id uuid not null references public.corrieri (id) on delete cascade,
  da_valore   numeric(12,3) default 0,   -- soglia iniziale sulla base (kg, colli, m³, m²)
  prezzo      numeric(12,2) default 0,   -- € per questo scaglione (forfait)
  ordine      int default 0
);
create index if not exists corr_scaglioni_idx on public.corrieri_scaglioni (corriere_id);

-- RLS: come catalogo/magazzino -> amministratore e commerciale
alter table public.corrieri            enable row level security;
alter table public.corrieri_scaglioni  enable row level security;

drop policy if exists corrieri_all on public.corrieri;
create policy corrieri_all on public.corrieri for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists corr_scaglioni_all on public.corrieri_scaglioni;
create policy corr_scaglioni_all on public.corrieri_scaglioni for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v35.
