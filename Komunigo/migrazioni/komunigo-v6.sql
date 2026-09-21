-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v6  (metodi di pagamento)
--
--  COSA FA (tutto ADDITIVO):
--   1) tabella komunigo_pagamenti: i metodi di pagamento offerti nel negozio
--      (carta, bonifico, ritiro, paypal), attivabili e configurabili dalle
--      Impostazioni del gestionale.
--   2) vista pubblica komunigo_pagamenti_pub: espone ad anon i metodi ATTIVI
--      (nome, descrizione, istruzioni) — MAI credenziali di gateway.
--   3) komunigo_ordini.pagamento_metodo: quale metodo ha scelto il cliente.
--
--  Le credenziali di Nexi/PayPal NON stanno qui: vivono nei SEGRETI delle
--  Edge Function. Qui c'è solo cosa mostrare al cliente.
--
--  Da eseguire UNA VOLTA: Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.komunigo_pagamenti (
  id          uuid primary key default gen_random_uuid(),
  metodo      text not null check (metodo in ('carta','bonifico','ritiro','paypal')),
  nome        text not null,
  descrizione text not null default '',
  istruzioni  text not null default '',     -- es. per bonifico: IBAN, intestatario, causale
  attivo      boolean not null default true,
  ordine      int not null default 0,
  creato_il   timestamptz not null default now(),
  unique (metodo)
);

comment on table public.komunigo_pagamenti is
  'Metodi di pagamento e-commerce Komunigo (nessuna credenziale gateway qui).';

alter table public.komunigo_pagamenti enable row level security;
drop policy if exists komunigo_pagamenti_all on public.komunigo_pagamenti;
create policy komunigo_pagamenti_all on public.komunigo_pagamenti for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

drop view if exists public.komunigo_pagamenti_pub;
create view public.komunigo_pagamenti_pub as
select metodo, nome, descrizione, istruzioni, ordine
from public.komunigo_pagamenti
where attivo = true;
grant select on public.komunigo_pagamenti_pub to anon, authenticated;

-- metodo scelto dal cliente sull'ordine
alter table public.komunigo_ordini
  add column if not exists pagamento_metodo text;

-- Metodi di partenza (se la tabella è vuota): personalizzali dalle Impostazioni.
--  carta/paypal DISATTIVI finché non sono collegati i gateway.
insert into public.komunigo_pagamenti (metodo, nome, descrizione, istruzioni, attivo, ordine)
select * from (values
  ('carta',    'Carta di credito',              'Paga subito e in sicurezza con carta (Visa, Mastercard).', '', false, 1),
  ('bonifico', 'Bonifico bancario anticipato',  'Ricevi i dati per il bonifico: l''ordine va in produzione alla ricezione del pagamento.',
     'Intestatario: CREATIO GROUP SRL' || chr(10) || 'IBAN: IT00 X000 0000 0000 0000 0000 000' || chr(10) || 'Banca: (da compilare)' || chr(10) || 'Causale: numero dell''ordine (es. K-2026-0001)', true, 2),
  ('ritiro',   'Pagamento al ritiro in sede',   'Paghi al momento del ritiro presso la nostra sede.', '', true, 3),
  ('paypal',   'PayPal',                        'Paga con il tuo conto PayPal o carta tramite PayPal.', '', false, 4)
) as v(metodo, nome, descrizione, istruzioni, attivo, ordine)
where not exists (select 1 from public.komunigo_pagamenti);

-- Fine migrazione Komunigo v6.
