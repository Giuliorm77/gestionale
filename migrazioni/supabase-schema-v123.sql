-- =====================================================================
--  Migrazione v123 — Allinea il vincolo imballi_voci.modo ai modi dell'app
--  L'app (MODI_VOCE) prevede anche: perimetro, scatola, mc, passaggio, battuta;
--  il vecchio check li rifiutava ("imballi_voci_modo_check").
--  Correttiva e reversibile.
-- =====================================================================

alter table public.imballi_voci drop constraint if exists imballi_voci_modo_check;
alter table public.imballi_voci add constraint imballi_voci_modo_check
  check (modo in ('mq','mtl','perimetro','scatola','mc','pz','ora','passaggio','battuta','fisso'));

-- Fine migrazione v123.
