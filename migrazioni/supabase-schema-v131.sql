-- =====================================================================
--  Migrazione v131 — Aggiunge il modo "pellicola" alle voci imballo
--  Pellicola alt. 50 cm: più giri per coprire il pannello
--  (giri = arrot.sup(L/50)+arrot.sup(H/50), metri = giri × perimetro).
--  Correttiva e reversibile.
-- =====================================================================

alter table public.imballi_voci drop constraint if exists imballi_voci_modo_check;
alter table public.imballi_voci add constraint imballi_voci_modo_check
  check (modo in ('mq','mtl','perimetro','pellicola','scatola','mc','pz','ora','passaggio','battuta','fisso'));

-- Fine migrazione v131.
