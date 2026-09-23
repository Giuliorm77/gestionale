-- =====================================================================
--  CRON promemoria CRM — chiama l'edge function "crm-promemoria" ogni 10'
--  Da eseguire UNA VOLTA nel SQL Editor, DOPO aver:
--    1) eseguito la migrazione v103
--    2) impostato i secret BREVO_API_KEY e CRON_SECRET
--    3) deployato l'edge function crm-promemoria
--  ⚠️ Sostituisci METTI_QUI_IL_CRON_SECRET con lo STESSO valore che hai
--     messo nel secret CRON_SECRET.
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- rimuove un eventuale job precedente con lo stesso nome (ri-eseguibile)
do $$ begin
  if exists (select 1 from cron.job where jobname = 'crm_promemoria_10min') then
    perform cron.unschedule('crm_promemoria_10min');
  end if;
end $$;

-- ogni 10 minuti
select cron.schedule('crm_promemoria_10min', '*/10 * * * *', $cron$
  select net.http_post(
    url     := 'https://xejakgjjvlivhlxzqksa.supabase.co/functions/v1/crm-promemoria',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-cron-secret', 'METTI_QUI_IL_CRON_SECRET'
               ),
    body    := '{}'::jsonb
  );
$cron$);

-- Per controllare i job attivi:      select * from cron.job;
-- Per vedere le ultime esecuzioni:   select * from cron.job_run_details order by start_time desc limit 20;
-- Per fermare i promemoria:          select cron.unschedule('crm_promemoria_10min');
