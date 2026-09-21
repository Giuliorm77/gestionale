-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v3  (opzioni di spedizione / trasporto)
--
--  COSA FA (tutto ADDITIVO):
--   1) tabella komunigo_spedizioni: le opzioni di consegna mostrate nel
--      carrello (es. Corriere Standard, Espresso, Ritiro in sede), con prezzo.
--   2) vista pubblica komunigo_spedizioni_pub: espone ad anon le opzioni attive.
--
--  I prezzi qui sono IMPONIBILI (netti): nel carrello l'IVA si applica come
--  per la merce. Gestione dalle Impostazioni del gestionale.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.komunigo_spedizioni (
  id          uuid primary key default gen_random_uuid(),
  nome        text        not null,                 -- "Corriere Standard"
  descrizione text        not null default '',      -- "Consegna in 3-5 gg lavorativi"
  prezzo      numeric(12,2) not null default 0,     -- costo netto (0 per il ritiro)
  ritiro      boolean     not null default false,   -- true = ritiro in sede (nessuna spedizione)
  ordine      int         not null default 0,
  attivo      boolean     not null default true,
  creato_il   timestamptz not null default now()
);

comment on table public.komunigo_spedizioni is
  'Opzioni di consegna e-commerce Komunigo (corrieri + ritiro) con prezzo netto.';

alter table public.komunigo_spedizioni enable row level security;

drop policy if exists komunigo_spedizioni_all on public.komunigo_spedizioni;
create policy komunigo_spedizioni_all on public.komunigo_spedizioni for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- vista pubblica: solo opzioni attive, ordinate
drop view if exists public.komunigo_spedizioni_pub;
create view public.komunigo_spedizioni_pub as
select id, nome, descrizione, prezzo, ritiro, ordine
from public.komunigo_spedizioni
where attivo = true;

comment on view public.komunigo_spedizioni_pub is
  'Opzioni di spedizione pubbliche Komunigo (solo attive).';

grant select on public.komunigo_spedizioni_pub to anon, authenticated;

-- Opzioni di partenza (se la tabella è vuota): puoi modificarle/eliminarle
-- dal gestionale (Impostazioni -> Spedizioni Komunigo).
insert into public.komunigo_spedizioni (nome, descrizione, prezzo, ritiro, ordine, attivo)
select * from (values
  ('Ritiro in sede',     'Ritiri gratis presso Creatio Group',        0.00, true,  0, true),
  ('Corriere Standard',  'Consegna in 3-5 giorni lavorativi',         9.90, false, 1, true),
  ('Corriere Espresso',  'Consegna in 24-48 ore',                    16.90, false, 2, true)
) as v(nome, descrizione, prezzo, ritiro, ordine, attivo)
where not exists (select 1 from public.komunigo_spedizioni);

-- Fine migrazione Komunigo v3.
