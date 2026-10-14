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

-- ---------------------------------------------------------------------
--  ZAINI E BORSE: modello separato con posizioni fronte, retro, alto fronte,
--  basso fronte (deciso da Giulio 2026-10-14). Assegnato in automatico a tutti
--  i prodotti del catalogo con categoria "Borse…" che non hanno già un modello.
-- ---------------------------------------------------------------------
do $$
declare v_b uuid;
begin
  select id into v_b from public.prodotti_config where nome = 'Stampa zaini e borse (modello)' limit 1;
  if v_b is null then
    insert into public.prodotti_config (nome, unita_calcolo, tipo, categoria, margine_pct, minimo,
                                        giorni_lavorazione, attivo, solo_modello, note)
    values ('Stampa zaini e borse (modello)', 'pz', 'gadget', 'Abbigliamento', 40, 10, 10, true, true,
            'Modello di stampa per zaini e borse del catalogo fornitore. AREE e PREZZI PROVVISORI.')
    returning id into v_b;
    insert into public.prodotti_config_fasce (prodotto_id, da_quantita, sconto_pct, ordine) values
      (v_b, 50, 5, 0), (v_b, 100, 10, 1);
  end if;
  insert into public.prodotti_config_stampe (prodotto_id, nome, area_cm, max_colori, prezzo_pz, setup, tecnica, ordine)
  select v_b, x.nome, x.area, 4, x.pz, x.setup, 'Serigrafia', x.ord
  from (values
    ('Fronte',       '20 × 20', 1.00, 30, 0),
    ('Retro',        '20 × 20', 1.00, 30, 1),
    ('Alto fronte',  '15 × 8',  0.80, 25, 2),
    ('Basso fronte', '15 × 8',  0.80, 25, 3)
  ) as x(nome, area, pz, setup, ord)
  where not exists (select 1 from public.prodotti_config_stampe s where s.prodotto_id = v_b and s.nome = x.nome);

  update public.catalogo_fornitore_prodotti
  set modello_stampa_id = v_b
  where fornitore = 'newwave' and categoria ilike 'borse%' and modello_stampa_id is null;
end $$;

-- controllo zaini/borse: posizioni + quanti prodotti lo usano
select s.ordine, s.nome, s.area_cm, s.prezzo_pz, s.setup,
       (select count(*) from public.catalogo_fornitore_prodotti p where p.modello_stampa_id = s.prodotto_id) as prodotti_assegnati
from public.prodotti_config_stampe s
join public.prodotti_config c on c.id = s.prodotto_id
where c.nome = 'Stampa zaini e borse (modello)'
order by s.ordine;

-- controllo: 8 posizioni serigrafia + 8 ricamo
select s.ordine, s.nome, s.area_cm, s.max_colori, s.tecnica, s.prezzo_pz, s.setup   -- 16 righe
from public.prodotti_config_stampe s
where s.prodotto_id = (select modello_stampa_id from public.catalogo_fornitore_sync where fornitore = 'newwave')
order by s.ordine;

-- Fine migrazione Komunigo v19.
