-- =====================================================================
--  CRON Scadenzario — sincronizza Fatture in Cloud 3 volte al giorno
--  Orari voluti (Italia): 08:00 / 13:00 / 18:00.
--  pg_cron gira in UTC: in ESTATE (CEST, UTC+2) uso 06/11/16 UTC = 08/13/18.
--  In INVERNO (CET, UTC+1) diventano 07/12/17 locali (sfaso di 1h, ininfluente).
--  >>> PRIMA DI LANCIARE: sostituisci <LA_TUA_ANON_KEY> con la anon public key
--      (Supabase → Project Settings → API → Project API keys → anon public).
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- rimuovi eventuali job precedenti con lo stesso nome (ignora l'errore se non esistono)
do $$ begin
  perform cron.unschedule('fic-sync-0800'); exception when others then null; end $$;
do $$ begin
  perform cron.unschedule('fic-sync-1300'); exception when others then null; end $$;
do $$ begin
  perform cron.unschedule('fic-sync-1800'); exception when others then null; end $$;

select cron.schedule('fic-sync-0800','0 6 * * *', $job$
  select net.http_post(
    url := 'https://xejakgjjvlivhlxzqksa.supabase.co/functions/v1/fic-sync',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer <LA_TUA_ANON_KEY>"}'::jsonb,
    body := '{}'::jsonb
  );
$job$);

select cron.schedule('fic-sync-1300','0 11 * * *', $job$
  select net.http_post(
    url := 'https://xejakgjjvlivhlxzqksa.supabase.co/functions/v1/fic-sync',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer <LA_TUA_ANON_KEY>"}'::jsonb,
    body := '{}'::jsonb
  );
$job$);

select cron.schedule('fic-sync-1800','0 16 * * *', $job$
  select net.http_post(
    url := 'https://xejakgjjvlivhlxzqksa.supabase.co/functions/v1/fic-sync',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer <LA_TUA_ANON_KEY>"}'::jsonb,
    body := '{}'::jsonb
  );
$job$);

-- Verifica i job creati:
--   select jobname, schedule, active from cron.job where jobname like 'fic-sync-%';
-- Storico esecuzioni:
--   select * from cron.job_run_details order by start_time desc limit 10;
