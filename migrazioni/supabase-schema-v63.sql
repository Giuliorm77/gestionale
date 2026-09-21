-- =====================================================================
--  MIGRAZIONE v63 - CODICE INTERNO automatico sugli articoli
--
--  Serve un identificativo NOSTRO, stabile e sempre presente, generato in
--  automatico a ogni inserimento (a mano o da import Excel).
--
--  Perche' un campo NUOVO e non `codice`:
--   - `codice` resta il codice "parlante" (MAT-FOREX-03-BN) o quello del
--     catalogo fornitore per i gadget (04PD388IT): compilato a mano, puo'
--     ripetersi o mancare;
--   - `codice_interno` e' garantito UNICO e presente su OGNI articolo.
--  Il codice del FORNITORE non si tocca: vive gia' in articoli_fornitori
--  (codice_fornitore), che permette piu' fornitori per articolo.
--
--  Formato: ART-00001, ART-00002, ...
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create sequence if not exists public.articoli_codice_seq;

alter table public.articoli add column if not exists codice_interno text;

-- Assegna il codice agli articoli gia' presenti (i 5.918 del catalogo).
update public.articoli
   set codice_interno = 'ART-' || lpad(nextval('public.articoli_codice_seq')::text, 5, '0')
 where codice_interno is null or codice_interno = '';

create unique index if not exists articoli_codice_interno_uidx
  on public.articoli (codice_interno);

-- Generazione automatica per ogni nuovo inserimento.
create or replace function public.set_codice_interno()
returns trigger
language plpgsql
as $$
begin
  if new.codice_interno is null or new.codice_interno = '' then
    new.codice_interno := 'ART-' || lpad(nextval('public.articoli_codice_seq')::text, 5, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_codice_interno on public.articoli;
create trigger trg_codice_interno
  before insert on public.articoli
  for each row execute function public.set_codice_interno();

-- Fine migrazione v63.
