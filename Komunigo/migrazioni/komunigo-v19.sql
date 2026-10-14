-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v19  (posizioni di stampa ABBIGLIAMENTO)
--
--  Posizioni standard decise da Giulio (2026-10-14) per magliette, felpe e
--  tutti i capi di abbigliamento:
--    lato cuore, lato destro, centro fronte, centro retro, manica sinistra,
--    manica destra, centro collo fronte, centro collo retro.
--
--  RICAMO: stesse 8 posizioni, tecnica "Ricamo", fino a 12 colori. Il prezzo del
--  ricamo è A PEZZO (non moltiplicato per i colori: lo gestisce il motore prezzi);
--  "setup" = punciatura del logo una tantum.
--
--  Agisce sul modello di stampa PREDEFINITO del catalogo New Wave
--  ("Stampa abbigliamento (modello)"). Le 4 posizioni esistenti vengono
--  RINOMINATE (tengono il loro id), le altre 4 AGGIUNTE.
--  AREE e PREZZI sono PROVVISORI (in attesa della tabellina): si correggono in
--  🧩 Prodotti config. › "Stampa abbigliamento (modello)".
--  Supabase -> SQL Editor -> Run. Sicura da ri-eseguire.
-- =====================================================================

do $$
declare v_mod uuid;
begin
  select modello_stampa_id into v_mod from public.catalogo_fornitore_sync where fornitore = 'newwave';
  if v_mod is null then raise exception 'Nessun modello di stampa predefinito per newwave (eseguire prima v17)'; end if;

  -- 1) rinomina le 4 posizioni create dalla v17
  update public.prodotti_config_stampe set nome = 'Lato cuore'      where prodotto_id = v_mod and nome = 'Petto lato cuore';
  update public.prodotti_config_stampe set nome = 'Centro fronte'   where prodotto_id = v_mod and nome = 'Fronte grande';
  update public.prodotti_config_stampe set nome = 'Centro retro'    where prodotto_id = v_mod and nome = 'Retro grande';
  update public.prodotti_config_stampe set nome = 'Manica sinistra' where prodotto_id = v_mod and nome = 'Manica';

  -- 2) aggiunge quelle mancanti (solo se non ci sono già)
  insert into public.prodotti_config_stampe (prodotto_id, nome, area_cm, max_colori, prezzo_pz, setup, tecnica, ordine)
  select v_mod, x.nome, x.area, x.maxc, x.pz, x.setup, 'Serigrafia', x.ord
  from (values
    ('Lato cuore',          '10 × 10', 4, 0.60, 25, 0),
    ('Lato destro',         '10 × 10', 4, 0.60, 25, 1),
    ('Centro fronte',       '30 × 40', 4, 1.20, 35, 2),
    ('Centro retro',        '30 × 40', 4, 1.20, 35, 3),
    ('Manica sinistra',     '8 × 8',   2, 0.60, 25, 4),
    ('Manica destra',       '8 × 8',   2, 0.60, 25, 5),
    ('Centro collo fronte', '8 × 4',   2, 0.60, 25, 6),
    ('Centro collo retro',  '8 × 4',   2, 0.60, 25, 7)
  ) as x(nome, area, maxc, pz, setup, ord)
  where not exists (select 1 from public.prodotti_config_stampe s where s.prodotto_id = v_mod and s.nome = x.nome);

  -- 2b) RICAMO: stesse posizioni, fino a 12 colori, prezzo a pezzo (provvisorio)
  insert into public.prodotti_config_stampe (prodotto_id, nome, area_cm, max_colori, prezzo_pz, setup, tecnica, ordine)
  select v_mod, x.nome, x.area, 12, x.pz, x.setup, 'Ricamo', x.ord
  from (values
    ('Ricamo lato cuore',          '10 × 10', 1.50, 20, 10),
    ('Ricamo lato destro',         '10 × 10', 1.50, 20, 11),
    ('Ricamo centro fronte',       '25 × 25', 4.00, 35, 12),
    ('Ricamo centro retro',        '25 × 25', 4.00, 35, 13),
    ('Ricamo manica sinistra',     '8 × 8',   1.20, 20, 14),
    ('Ricamo manica destra',       '8 × 8',   1.20, 20, 15),
    ('Ricamo centro collo fronte', '8 × 4',   1.20, 20, 16),
    ('Ricamo centro collo retro',  '8 × 4',   1.20, 20, 17)
  ) as x(nome, area, pz, setup, ord)
  where not exists (select 1 from public.prodotti_config_stampe s where s.prodotto_id = v_mod and s.nome = x.nome);

  -- 3) ordine di visualizzazione come da elenco
  update public.prodotti_config_stampe s set ordine = x.ord
  from (values ('Lato cuore',0),('Lato destro',1),('Centro fronte',2),('Centro retro',3),
               ('Manica sinistra',4),('Manica destra',5),('Centro collo fronte',6),('Centro collo retro',7)) as x(nome, ord)
  where s.prodotto_id = v_mod and s.nome = x.nome;
end $$;

-- controllo: 8 posizioni serigrafia + 8 ricamo
select s.ordine, s.nome, s.area_cm, s.max_colori, s.tecnica, s.prezzo_pz, s.setup   -- 16 righe
from public.prodotti_config_stampe s
where s.prodotto_id = (select modello_stampa_id from public.catalogo_fornitore_sync where fornitore = 'newwave')
order by s.ordine;

-- Fine migrazione Komunigo v19.
