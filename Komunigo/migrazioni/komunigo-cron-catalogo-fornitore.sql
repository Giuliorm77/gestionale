-- =====================================================================
--  CRON Catalogo fornitore — riscarica il catalogo New Wave ogni LUNEDÌ
--  alle 07:00 circa (05:00 UTC). Il portale NWG rigenera l'export una volta
--  a settimana: se in futuro passa a giornaliero, cambiare '0 5 * * 1'
--  in '0 5 * * *'.
--  >>> PRIMA DI LANCIARE: sostituisci <LA_TUA_ANON_KEY> con la anon public key
--      (Supabase → Project Settings → API → Project API keys → anon public).
--  Richiede: migrazione komunigo-v16.sql + edge function catalogo-fornitore
--  deployata + secret NEWWAVE_FEED_URL.
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$ begin
  perform cron.unschedule('catalogo-fornitore-settimanale'); exception when others then null; end $$;

select cron.schedule('catalogo-fornitore-settimanale','0 5 * * 1', $job$
  select net.http_post(
    url := 'https://xejakgjjvlivhlxzqksa.supabase.co/functions/v1/catalogo-fornitore',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer <LA_TUA_ANON_KEY>"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);

-- Per toglierlo: select cron.unschedule('catalogo-fornitore-settimanale');
