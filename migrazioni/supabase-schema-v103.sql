-- =====================================================================
--  Migrazione v103 — Promemoria CRM via EMAIL
--  Aggiunge il tracciamento "email inviata" sulle attività CRM e una
--  funzione che elenca i promemoria SCADUTI e non ancora notificati,
--  con l'email del destinatario (chi ha creato l'attività).
--  La funzione la chiamerà SOLO l'edge function "crm-promemoria"
--  (con la service_role key). Additiva e sicura.
-- =====================================================================

-- 1) Colonna anti-doppio-invio
alter table public.crm_attivita
  add column if not exists promemoria_inviato_il timestamptz;

-- indice per la scansione dei promemoria da inviare
create index if not exists idx_att_promemoria_todo
  on public.crm_attivita(promemoria_il)
  where completata = false and promemoria_inviato_il is null;

-- 2) Elenco promemoria da inviare (scaduti, non completati, non ancora inviati)
--    Joina profiles + auth.users per ottenere l'email di chi deve essere avvisato.
--    security definer: gira come owner (postgres) → può leggere auth.users.
create or replace function public.promemoria_da_inviare()
returns table(
  id            uuid,
  titolo        text,
  note          text,
  promemoria_il timestamptz,
  email         text,
  nome          text
)
language sql
security definer
set search_path = public
as $$
  select
    a.id,
    'CRM · ' || coalesce(t.l, '') ||
      case when cl.ragione_sociale is not null then ' — ' || cl.ragione_sociale else '' end
      as titolo,
    trim(both e'\n' from
      coalesce(case when a.esito   is not null and a.esito <> '' then 'Esito: ' || a.esito else '' end, '') ||
      case when a.note is not null and a.note <> '' then e'\n' || a.note else '' end
    ) as note,
    a.promemoria_il,
    u.email::text,
    p.nome
  from public.crm_attivita a
  left join public.clienti  cl on cl.id = a.cliente_id
  left join public.profiles p  on p.id  = a.creato_da
  left join auth.users      u  on u.id  = a.creato_da
  left join (values
      ('chiamata','Chiamata'),('visita','Visita'),('email','Email'),
      ('nota','Nota'),('appuntamento','Appuntamento')
    ) as t(k,l) on t.k = a.tipo
  where a.completata = false
    and a.promemoria_il is not null
    and a.promemoria_il <= now()
    and a.promemoria_il >= now() - interval '2 days'   -- non spammare promemoria vecchissimi
    and a.promemoria_inviato_il is null
    and u.email is not null;
$$;

-- 3) Segna come inviati (chiamata dall'edge function dopo l'invio riuscito)
create or replace function public.segna_promemoria_inviato(p_ids uuid[])
returns integer
language sql
security definer
set search_path = public
as $$
  with upd as (
    update public.crm_attivita
       set promemoria_inviato_il = now()
     where id = any(p_ids)
     returning 1
  )
  select count(*)::int from upd;
$$;

-- 4) Blindatura: solo la service_role (edge function) può usarle.
revoke all on function public.promemoria_da_inviare()          from public, anon, authenticated;
revoke all on function public.segna_promemoria_inviato(uuid[]) from public, anon, authenticated;
grant execute on function public.promemoria_da_inviare()          to service_role;
grant execute on function public.segna_promemoria_inviato(uuid[]) to service_role;

-- Fine migrazione v103.
