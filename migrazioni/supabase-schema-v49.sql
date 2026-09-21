-- =====================================================================
--  MIGRAZIONE v49 - AVANZI/LASTRE: pezzi di materiale tracciati con QR (FASE A)
--
--  Fondazione del sistema di tracciamento materiale a QR:
--   - ogni pezzo fisico (lastra intera o avanzo) = una riga con un CODICE
--     (contenuto del QR), le sue MISURE, uno STATO e il pezzo PADRE da cui viene;
--   - il VALORE (costo) del pezzo è ECONOMICO: NON deve vederlo il magazzino.
--
--  Come per il ruolo magazzino: la tabella base (con il costo) è riservata a
--  admin/commerciale; il magazzino usa una VISTA senza costi per elencare i pezzi
--  e una FUNZIONE dedicata per registrarli (così non tocca né vede il costo).
--
--  FASE A = modello + PRELIEVO (nascita del pezzo: aggancio commessa, scarico
--  della neutra in mq, etichetta). RIENTRO dell'avanzo (nuova etichetta) = Fase B;
--  valorizzazione e perdita-per-errore che intacca il margine = Fase C.
--
--  Additiva: crea solo oggetti nuovi. Da eseguire in Supabase -> SQL Editor -> Run.
-- =====================================================================

create sequence if not exists public.magazzino_pezzi_seq;

create table if not exists public.magazzino_pezzi (
  id             uuid primary key default gen_random_uuid(),
  codice         text unique not null,                 -- contenuto del QR (es. PZ-000123)
  articolo_id    uuid references public.articoli (id), -- che materiale (Forex 3mm, ...)
  pezzo_padre_id uuid references public.magazzino_pezzi (id), -- da quale lastra proviene (se avanzo)
  larghezza_cm   numeric(10,1),
  altezza_cm     numeric(10,1),
  spessore_mm    numeric(10,2),
  quantita       int not null default 1,               -- pezzi identici (di norma 1)
  -- ECONOMICO (nascosto al magazzino):
  costo          numeric(12,2),                        -- valore del pezzo
  valorizzazione text not null default 'acquisto'
                 check (valorizzazione in ('acquisto','zero','manuale')),
  -- OPERATIVO:
  stato          text not null default 'in_magazzino'
                 check (stato in ('in_magazzino','uscito','consumato','rientrato','perso')),
  commessa_id    uuid references public.commesse (id), -- a quale commessa è agganciato quando esce
  ubicazione     text default '',
  note           text default '',
  creato_il      timestamptz not null default now(),
  creato_da      uuid
);
create index if not exists mp_articolo_idx on public.magazzino_pezzi (articolo_id);
create index if not exists mp_stato_idx    on public.magazzino_pezzi (stato);
create index if not exists mp_padre_idx    on public.magazzino_pezzi (pezzo_padre_id);

alter table public.magazzino_pezzi enable row level security;

-- Tabella base (INCLUDE il costo) = solo economici (admin/commerciale).
drop policy if exists mp_econ on public.magazzino_pezzi;
create policy mp_econ on public.magazzino_pezzi for all to authenticated
  using (public.ruolo_utente() in ('amministratore','commerciale'))
  with check (public.ruolo_utente() in ('amministratore','commerciale'));

-- ---------------------------------------------------------------------
-- VISTA SENZA COSTI: il magazzino/produzione elencano i pezzi da qui.
--  (owner postgres -> bypassa la RLS della base, ma NON espone costo/valorizzazione)
-- ---------------------------------------------------------------------
drop view if exists public.magazzino_pezzi_op;
create view public.magazzino_pezzi_op as
select
  p.id, p.codice, p.articolo_id, p.pezzo_padre_id,
  p.larghezza_cm, p.altezza_cm, p.spessore_mm, p.quantita,
  round((coalesce(p.larghezza_cm,0)*coalesce(p.altezza_cm,0)/10000.0)*p.quantita, 3) as mq,
  p.stato, p.commessa_id, p.ubicazione, p.note, p.creato_il,
  a.nome_articolo, a.codice as articolo_codice, a.unita,
  c.numero as commessa_numero
from public.magazzino_pezzi p
left join public.articoli a on a.id = p.articolo_id
left join public.commesse c on c.id = p.commessa_id
where public.ruolo_utente() in ('amministratore','commerciale','magazzino','produzione');

grant select on public.magazzino_pezzi_op to authenticated;

-- ---------------------------------------------------------------------
-- FUNZIONE preleva_per_commessa: il magazzino PREPARA il materiale per una
--  commessa. Il pezzo tracciato NASCE QUI (con il suo codice/etichetta): crea il
--  pezzo con le sue misure, lo aggancia alla commessa (stato 'uscito') e SCARICA
--  dalla giacenza NEUTRA i mq corrispondenti. Le lastre neutre restano stock a
--  quantità (giacenza normale); il pezzo tracciato è ciò che ESCE verso la commessa.
--  SECURITY DEFINER: accetta solo campi operativi, non tocca né restituisce il
--  costo (che il commerciale valorizza dopo).
-- ---------------------------------------------------------------------
create or replace function public.preleva_per_commessa(
  p_articolo_id uuid,
  p_commessa_id uuid,
  p_larghezza numeric default null,
  p_altezza numeric default null,
  p_spessore numeric default null,
  p_quantita int default 1,
  p_ubicazione text default '',
  p_note text default ''
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ruolo text := public.ruolo_utente();
  v_codice text;
  v_num text;
  v_mq numeric;
begin
  if v_ruolo is null or v_ruolo not in ('amministratore','commerciale','magazzino') then
    raise exception 'Non autorizzato';
  end if;
  v_codice := 'PZ-' || lpad(nextval('public.magazzino_pezzi_seq')::text, 6, '0');
  insert into public.magazzino_pezzi
    (codice, articolo_id, larghezza_cm, altezza_cm, spessore_mm, quantita,
     stato, commessa_id, ubicazione, note, creato_da)
  values
    (v_codice, p_articolo_id, p_larghezza, p_altezza, p_spessore, coalesce(p_quantita,1),
     'uscito', p_commessa_id, coalesce(p_ubicazione,''), coalesce(p_note,''), auth.uid());
  -- scarico della lastra neutra (in mq) se abbiamo le misure
  v_mq := (coalesce(p_larghezza,0) * coalesce(p_altezza,0) / 10000.0) * coalesce(p_quantita,1);
  if v_mq > 0 and p_articolo_id is not null then
    select numero into v_num from public.commesse where id = p_commessa_id;
    insert into public.movimenti_magazzino (articolo_id, tipo, quantita, causale, riferimento, creato_da)
    values (p_articolo_id, 'scarico', v_mq, 'Prelievo per lavorazione',
            'Commessa ' || coalesce(v_num, p_commessa_id::text), auth.uid());
  end if;
  return v_codice;
end;
$$;

grant execute on function public.preleva_per_commessa(uuid,uuid,numeric,numeric,numeric,int,text,text) to authenticated;

-- Fine migrazione v49 (Fase A: modello pezzi + QR + registrazione).
