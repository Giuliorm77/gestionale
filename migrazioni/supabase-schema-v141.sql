-- =====================================================================
--  Migrazione v141 — Materiale a FORMATI (bobine / lastre) per nesting e resa
--  Un materiale può avere i suoi formati disponibili:
--   - bobina: lista di altezze (cm) — larghezza=altezza, lunghezza infinita; prezzo a €/mq
--   - lastra: lista di misure standard (L×H cm)
--  Usati nel preventivo per scegliere il formato migliore (resa) e, per le lastre,
--  interrogare il magazzino con tolleranza.
--  - materiale_tipo: '' | 'bobina' | 'lastra'
--  - formati: jsonb  ({altezze:[...]} per bobina; {misure:[{l,h}], tolleranza_cm} per lastra)
--  Additiva e reversibile.
-- =====================================================================

alter table public.articoli
  add column if not exists materiale_tipo text,
  add column if not exists formati        jsonb;

-- Fine migrazione v141.
-- (Per annullare: alter table public.articoli drop column materiale_tipo, drop column formati;)
