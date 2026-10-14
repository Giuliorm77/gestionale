-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v22  (consenso alle offerte via email)
--
--  Per scaricare template e tracciati bisogna essere registrati. Nella
--  registrazione c'è un consenso FACOLTATIVO (non pre-spuntato) a ricevere
--  offerte e novità via email: lo salviamo con data e fonte (prova GDPR) ed è
--  revocabile dall'area account.
--  - komunigo_account.consenso_marketing / _il / _fonte
--  - handle_new_user(): identica alla v12 + legge il consenso dai metadati
--    della registrazione (così vale anche se il cliente conferma l'email dopo)
--  - il cliente può cambiare solo il proprio consenso (grant di colonna)
--  Additiva. Supabase -> SQL Editor -> Run. Sicura da rieseguire.
-- =====================================================================

alter table public.komunigo_account
  add column if not exists consenso_marketing    boolean not null default false,
  add column if not exists consenso_marketing_il timestamptz,
  add column if not exists consenso_marketing_fonte text not null default '';

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_cons boolean := coalesce(new.raw_user_meta_data->>'consenso_marketing','') = 'true';
begin
  if coalesce(new.raw_user_meta_data->>'komunigo','') = 'true' then
    insert into public.komunigo_account (id, email, nome, azienda, telefono,
                                         consenso_marketing, consenso_marketing_il, consenso_marketing_fonte)
    values (new.id, new.email,
      coalesce(new.raw_user_meta_data->>'nome',''),
      coalesce(new.raw_user_meta_data->>'azienda',''),
      coalesce(new.raw_user_meta_data->>'telefono',''),
      v_cons, case when v_cons then now() end, case when v_cons then 'registrazione' else '' end)
    on conflict (id) do nothing;
  else
    insert into public.profiles (id, nome, ruolo)
    values (new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)), 'reception')
    on conflict (id) do nothing;
  end if;
  return new;
end $$;

-- il cliente può dare/revocare il proprio consenso (le altre colonne restano come in v14)
grant update (consenso_marketing, consenso_marketing_il, consenso_marketing_fonte)
  on public.komunigo_account to authenticated;

-- controllo
select count(*) filter (where consenso_marketing) as con_consenso, count(*) as account
from public.komunigo_account;

-- Fine migrazione Komunigo v22.
