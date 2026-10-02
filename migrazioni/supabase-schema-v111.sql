-- =====================================================================
--  Migrazione v111 — Fornitore del PREZZO d'acquisto su righe preventivo/commessa
--  Traccia QUALE fornitore ci ha fatto quel prezzo di acquisto (+ nota:
--  data/riferimento/validita' offerta), cosi' se chi l'ha contattato non c'e'
--  gli altri sanno con chi parlare. Dato INTERNO (non sul PDF cliente).
--  Si copia dal preventivo alla commessa e precompila l'ordine fornitore.
--  Additiva e reversibile.
-- =====================================================================

alter table public.preventivi_righe
  add column if not exists fornitore_prezzo_id   uuid references public.fornitori(id) on delete set null,
  add column if not exists fornitore_prezzo_nome text,
  add column if not exists fornitore_prezzo_nota text;

alter table public.commesse_righe
  add column if not exists fornitore_prezzo_id   uuid references public.fornitori(id) on delete set null,
  add column if not exists fornitore_prezzo_nome text,
  add column if not exists fornitore_prezzo_nota text;

-- Fine migrazione v111.
-- (Per annullare:
--   alter table public.preventivi_righe drop column fornitore_prezzo_id, drop column fornitore_prezzo_nome, drop column fornitore_prezzo_nota;
--   alter table public.commesse_righe  drop column fornitore_prezzo_id, drop column fornitore_prezzo_nome, drop column fornitore_prezzo_nota;)
