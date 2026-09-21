-- =====================================================================
--  MIGRAZIONE v78 - PIN operatore per la Postazione
--
--  Sulla postazione condivisa ogni operatore deve confermare con un PIN,
--  altrimenti chiunque puo' timbrare a nome di un altro.
--  - operatori.pin: il codice (impostato dall'amministratore).
--  - verifica_pin_operatore(): controlla il PIN LATO SERVER, cosi' il PIN
--    non viaggia mai verso il client in chiaro.
--  - operatori_nomi: espone solo "has_pin" (se ne ha uno), MAI il PIN.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.operatori add column if not exists pin text default '';

-- Vista pubblica (senza PIN): aggiunge solo il flag has_pin
create or replace view public.operatori_nomi as
  select id, nome, tipo, (pin is not null and pin <> '') as has_pin from public.operatori;
grant select on public.operatori_nomi to authenticated;

-- Verifica del PIN lato server (il PIN non esce mai dal database)
create or replace function public.verifica_pin_operatore(p_operatore_id uuid, p_pin text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(
    select 1 from public.operatori
     where id = p_operatore_id
       and pin is not null and pin <> ''
       and pin = p_pin
  );
$$;
grant execute on function public.verifica_pin_operatore(uuid, text) to authenticated;

-- Fine migrazione v78.
