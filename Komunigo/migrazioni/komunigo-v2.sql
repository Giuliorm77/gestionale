-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v2  (schede e-commerce + template PDF)
--
--  COSA FA (tutto ADDITIVO):
--   1) tabella komunigo_schede: contenuto "vetrina" per OGNI prodotto pubblicato
--      (sia articoli a magazzino sia configuratori su misura): descrizione,
--      caratteristiche, immagini di galleria, PDF del layout/template.
--   2) vista pubblica komunigo_schede_pub: espone ad anon solo i campi vetrina
--      (contenuto marketing, nessun costo) delle schede attive.
--   3) bucket Storage komunigo-public (lettura pubblica; scrittura solo staff)
--      dove vivono immagini di galleria e i PDF template.
--
--  SICUREZZA: scrittura schede/file consentita solo ad amministratore/commerciale
--  (stesso pattern di prodotti_config, via public.ruolo_utente()). La lettura
--  pubblica passa dalla vista (senza RLS della tabella) e dal bucket pubblico.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELLA SCHEDE E-COMMERCE
--    Una riga per prodotto pubblicato. tipo+ref_id identificano il prodotto:
--      tipo='articolo'      -> ref_id = articoli.id       (prodotto a magazzino)
--      tipo='configuratore' -> ref_id = prodotti_config.id (prodotto su misura)
-- ---------------------------------------------------------------------
create table if not exists public.komunigo_schede (
  id              uuid primary key default gen_random_uuid(),
  tipo            text not null check (tipo in ('articolo','configuratore')),
  ref_id          uuid not null,
  slug            text unique,                                   -- per URL leggibili (facoltativo)
  sottotitolo     text        not null default '',
  descrizione     text        not null default '',              -- testo lungo (a capo ammessi)
  caratteristiche jsonb       not null default '[]'::jsonb,      -- [{"label":"Materiale","valore":"Forex 5mm"}, ...]
  immagini        jsonb       not null default '[]'::jsonb,      -- [{"path":"gallery/xxx.jpg","alt":"..."}, ...] nel bucket komunigo-public
  template_path   text,                                          -- PDF del layout nel bucket komunigo-public (es. template/xxx.pdf)
  template_nome   text,                                          -- nome mostrato del file (es. "Template Forex 100x70.pdf")
  template_note   text        not null default '',               -- istruzioni ("posiziona la grafica dentro il tratteggio…")
  attivo          boolean     not null default true,
  creato_il       timestamptz not null default now(),
  aggiornato_il   timestamptz not null default now(),
  unique (tipo, ref_id)
);

comment on table public.komunigo_schede is
  'Contenuto vetrina e-commerce Komunigo per prodotto (articolo o configuratore): descrizione, caratteristiche, immagini, PDF template.';

alter table public.komunigo_schede enable row level security;

drop policy if exists komunigo_schede_all on public.komunigo_schede;
create policy komunigo_schede_all on public.komunigo_schede for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---------------------------------------------------------------------
-- 2. VISTA PUBBLICA  (solo schede attive, solo campi vetrina)
--    Owner postgres, senza security_invoker -> anon legge la proiezione sicura.
-- ---------------------------------------------------------------------
drop view if exists public.komunigo_schede_pub;
create view public.komunigo_schede_pub as
select
  s.tipo,
  s.ref_id,
  s.slug,
  s.sottotitolo,
  s.descrizione,
  s.caratteristiche,
  s.immagini,
  s.template_path,
  s.template_nome,
  s.template_note
from public.komunigo_schede s
where s.attivo = true;

comment on view public.komunigo_schede_pub is
  'Schede vetrina Komunigo (solo attive, solo contenuti pubblici).';

grant select on public.komunigo_schede_pub to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. BUCKET STORAGE  komunigo-public  (immagini galleria + PDF template)
--    Pubblico in LETTURA (URL diretti); SCRITTURA solo staff.
--    Se questo blocco desse errore di permessi, crea il bucket a mano:
--    Storage -> New bucket -> nome "komunigo-public" -> Public: ON.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('komunigo-public', 'komunigo-public', true)
on conflict (id) do update set public = true;

-- scrittura (upload/aggiorna/elimina) solo ad amministratore/commerciale
drop policy if exists komunigo_public_write on storage.objects;
create policy komunigo_public_write on storage.objects for all to authenticated
  using      (bucket_id = 'komunigo-public' and public.ruolo_utente() in ('amministratore','commerciale'))
  with check (bucket_id = 'komunigo-public' and public.ruolo_utente() in ('amministratore','commerciale'));

-- lettura pubblica: i bucket "public" sono già serviti in lettura senza RLS,
-- ma aggiungiamo una policy esplicita di SELECT per sicurezza/compatibilità.
drop policy if exists komunigo_public_read on storage.objects;
create policy komunigo_public_read on storage.objects for select to anon, authenticated
  using (bucket_id = 'komunigo-public');

-- Fine migrazione Komunigo v2.
