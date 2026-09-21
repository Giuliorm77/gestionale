-- =====================================================================
--  Migrazione v60 — RICERCA CATALOGO LATO SERVER
--
--  Perche': il Catalogo (e i selettori articolo) scaricavano TUTTA la
--  tabella articoli e filtravano nel browser. Supabase restituisce al
--  massimo 1000 righe per richiesta: con 5.918 articoli in catalogo,
--  ~4.900 articoli erano invisibili e non cercabili da nessuna parte.
--
--  Da qui in avanti la ricerca la fa Postgres (ilike con indici trigram)
--  e l'app scarica solo la pagina che serve. Regge tranquillamente
--  20.000+ articoli.
-- =====================================================================

create extension if not exists pg_trgm;

-- Indici trigram: servono per le ricerche "contiene" (%forex%).
-- Senza, ogni ricerca sarebbe una scansione completa della tabella.
create index if not exists articoli_nome_trgm
  on public.articoli using gin (nome_articolo gin_trgm_ops);
create index if not exists articoli_codice_trgm
  on public.articoli using gin (codice gin_trgm_ops);
create index if not exists articoli_descrizione_trgm
  on public.articoli using gin (descrizione_articolo gin_trgm_ops);

-- Indice per l'ordinamento + paginazione dell'elenco.
create index if not exists articoli_nome_idx
  on public.articoli (nome_articolo);

-- Indice per il filtro categoria.
create index if not exists articoli_categoria_idx
  on public.articoli (categoria);

-- ---------------------------------------------------------------------
--  Elenco categorie distinte.
--  Prima le categorie venivano dedotte dalle righe caricate: con il
--  limite di 1000 righe, il menu a tendina mostrava solo le categorie
--  dei primi 1000 articoli in ordine alfabetico.
--  Funzione SQL normale = security invoker = la RLS di articoli continua
--  ad applicarsi a chi chiama (nessun accesso in piu' per nessuno).
-- ---------------------------------------------------------------------
create or replace function public.categorie_articoli()
returns table (categoria text)
language sql
stable
as $$
  select distinct a.categoria
  from public.articoli a
  where a.categoria is not null and a.categoria <> ''
  order by 1
$$;

grant execute on function public.categorie_articoli() to authenticated;

-- Fine migrazione v60.
