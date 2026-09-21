-- =====================================================================
--  MIGRAZIONE v29 - Righe articolo della commessa + data consegna per riga
--
--  Gli articoli del preventivo diventano RIGHE della commessa. Ogni riga ha
--  la sua DATA DI CONSEGNA. La data e' obbligatoria: la regola e' applicata
--  nell'app (blocca il salvataggio per QUALSIASI ruolo). In DB la colonna
--  resta annullabile solo per non generare errori grezzi durante le bozze.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

create table if not exists public.commesse_righe (
  id            uuid primary key default gen_random_uuid(),
  commessa_id   uuid not null references public.commesse (id) on delete cascade,
  ordine        int default 0,
  descrizione   text default '',
  articolo_id   uuid references public.articoli (id),
  quantita      numeric(12,2) default 0,
  unita         text default '',
  data_consegna date,                       -- OBBLIGATORIA (validata nell'app)
  stato         text not null default 'da_produrre'
                check (stato in ('da_produrre','in_produzione','pronto','consegnato')),
  note          text default '',
  config        jsonb                       -- composizione ereditata dal preventivo (facolt.)
);
create index if not exists righe_commessa_idx on public.commesse_righe (commessa_id);

-- RLS: come le commesse -> amministratore, commerciale, produzione
alter table public.commesse_righe enable row level security;

drop policy if exists commesse_righe_all on public.commesse_righe;
create policy commesse_righe_all on public.commesse_righe for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale','produzione'))
  with check (public.ruolo_utente() in ('amministratore','commerciale','produzione'));

-- Fine migrazione v29.
