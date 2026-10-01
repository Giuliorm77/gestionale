-- =====================================================================
--  Migrazione v109 — Contatto WhatsApp su clienti e fornitori
--  Campo libero (numero) usato per aprire la chat WhatsApp (wa.me).
--  Additiva e reversibile.
-- =====================================================================

alter table public.clienti   add column if not exists whatsapp text;
alter table public.fornitori add column if not exists whatsapp text;

-- Fine migrazione v109.
-- (Per annullare: alter table public.clienti drop column whatsapp; alter table public.fornitori drop column whatsapp;)
