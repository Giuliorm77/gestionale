-- =====================================================================
--  MIGRAZIONE v92 - % abbondanza stampa (smarginatura + crocini) sulle lastre
--
--  Le lastre non si stampano mai a formato finito: serve sempre una % di
--  abbondanza sul materiale. Default globale in impostazioni (2%), con
--  override sul singolo preventivo. Dove la variante del prodotto ha già
--  uno sfrido, quello vince; altrimenti si applica questo default.
--
--  Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

alter table public.impostazioni add column if not exists abbondanza_pct numeric default 2;
update public.impostazioni set abbondanza_pct = 2 where abbondanza_pct is null;

alter table public.preventivi add column if not exists abbondanza_pct numeric;

-- Fine migrazione v92.
