-- =====================================================================
--  Migrazione v139 — Operatore sulla manodopera del preventivo
--  La stessa lavorazione a tempo costa (e si vende) diversamente a seconda
--  di CHI la fa. Sulla scheda operatore ora c'è anche la VENDITA al cliente
--  (€/h), oltre al costo azienda. In preventivo si sceglie l'operatore e la
--  riga prende costo + prezzo da lì.
--  - operatori.vendita_oraria: prezzo di vendita al cliente (€/h)
--  - preventivi_righe / commesse_righe: operatore_id + operatore_nome
--  Additiva e reversibile.
-- =====================================================================

alter table public.operatori
  add column if not exists vendita_oraria numeric not null default 0;

alter table public.preventivi_righe
  add column if not exists operatore_id   text,
  add column if not exists operatore_nome text;

alter table public.commesse_righe
  add column if not exists operatore_id   text,
  add column if not exists operatore_nome text;

-- Fine migrazione v139.
-- (Per annullare:
--   alter table public.operatori drop column vendita_oraria;
--   alter table public.preventivi_righe drop column operatore_id, drop column operatore_nome;
--   alter table public.commesse_righe drop column operatore_id, drop column operatore_nome;)
