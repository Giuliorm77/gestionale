-- =====================================================================
--  Migrazione v129 — FIX vincolo ddt_righe -> commesse_righe (ON DELETE SET NULL)
--  Il vincolo bloccava la cancellazione delle righe di commessa collegate a un DDT,
--  causando il RADDOPPIO delle righe a ogni salvataggio. Con ON DELETE SET NULL,
--  cancellare una riga di commessa azzera solo il collegamento sul DDT (già emesso).
--  Correttiva e reversibile.
-- =====================================================================

-- Rimuove QUALSIASI foreign key su ddt_righe che coinvolge commessa_riga_id
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.ddt_righe'::regclass and contype = 'f'
      and pg_get_constraintdef(oid) ilike '%(commessa_riga_id)%'
  loop
    execute 'alter table public.ddt_righe drop constraint ' || quote_ident(c.conname);
  end loop;
end $$;

-- Ricrea il collegamento con ON DELETE SET NULL
alter table public.ddt_righe
  add constraint ddt_righe_commessa_riga_id_fkey
  foreign key (commessa_riga_id) references public.commesse_righe(id) on delete set null;

-- Fine migrazione v129.
