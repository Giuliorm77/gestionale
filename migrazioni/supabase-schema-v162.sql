-- =====================================================================
--  Migrazione v162 — Registro pagamenti provvigioni agli agenti
--  Permette di vedere, per agente: maturato su incassato (RPC provvigioni_incassato)
--  meno quanto gia' pagato = residuo da pagare.
--  Qui si registrano i pagamenti effettivi (liquidazioni) all'agente.
-- =====================================================================

create table if not exists public.provvigioni_pagamenti (
  id uuid primary key default gen_random_uuid(),
  agente_id uuid not null references public.agenti(id) on delete cascade,
  data date not null default current_date,
  importo numeric(12,2) not null default 0,
  metodo text default '',
  riferimento text default '',
  note text default '',
  creato_da uuid,
  creato_il timestamptz default now()
);

create index if not exists provv_pag_agente_idx on public.provvigioni_pagamenti(agente_id);

alter table public.provvigioni_pagamenti enable row level security;

drop policy if exists provv_pag_select on public.provvigioni_pagamenti;
create policy provv_pag_select on public.provvigioni_pagamenti for select to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'));

drop policy if exists provv_pag_write on public.provvigioni_pagamenti;
create policy provv_pag_write on public.provvigioni_pagamenti for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- Fine migrazione v162.
