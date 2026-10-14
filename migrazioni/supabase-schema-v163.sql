-- =====================================================================
--  Migrazione v163 — Promemoria CRM email: aggiunge RIFERIMENTI contatto
--  L'email di promemoria ora porta anche con CHI è l'attività e come
--  contattarlo (cliente/nominativo, referente/persona, telefono, email),
--  per agire più in fretta.
--  Cambia il tipo di ritorno di promemoria_da_inviare() -> serve DROP.
-- =====================================================================

drop function if exists public.promemoria_da_inviare();

create or replace function public.promemoria_da_inviare()
returns table(
  id            uuid,
  titolo        text,
  note          text,
  promemoria_il timestamptz,
  email         text,
  nome          text,
  contatto      text,     -- cliente (ragione sociale) o nominativo libero
  referente     text,     -- persona con cui parlare
  telefono      text,     -- recapito telefonico del cliente
  email_rif     text      -- email di riferimento del cliente
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
      coalesce(case when a.esito is not null and a.esito <> '' then 'Esito: ' || a.esito else '' end, '') ||
      case when a.note is not null and a.note <> '' then e'\n' || a.note else '' end
    ) as note,
    a.promemoria_il,
    u.email::text,
    p.nome,
    coalesce(nullif(cl.ragione_sociale,''), nullif(a.contatto,'')) as contatto,
    nullif(a.referente,'') as referente,
    coalesce(nullif(cl.telefono,''), nullif(cl.cellulare,'')) as telefono,
    (select e.indirizzo from public.clienti_email e
       where e.cliente_id = a.cliente_id
       order by case e.categoria when 'commerciale' then 0 when 'ordini' then 1
                                 when 'generica' then 2 when 'amministrazione' then 3 else 4 end
       limit 1) as email_rif
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
    and a.promemoria_il >= now() - interval '2 days'
    and a.promemoria_inviato_il is null
    and u.email is not null;
$$;

revoke all on function public.promemoria_da_inviare() from public, anon, authenticated;
grant execute on function public.promemoria_da_inviare() to service_role;

-- Fine migrazione v163.
