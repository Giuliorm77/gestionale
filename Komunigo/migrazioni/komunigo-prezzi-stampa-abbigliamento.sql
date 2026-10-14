-- =====================================================================
--  PREZZI DI STAMPA ABBIGLIAMENTO (modello di stampa predefinito New Wave)
--  Allineati a Stampasi (ottobre 2026). Sono COSTI: il sistema aggiunge il
--  margine del modello (40% → costo / 0,6) e gli sconti quantità (−5% da 50,
--  −10% da 100). Risultato fronte 1 colore: ~1,50 €/capo a 30 pz, ~0,93 a 100,
--  ~0,79 a 500.
--  Supabase -> SQL Editor -> Run. Si può rieseguire. Dopo si possono
--  ritoccare a mano in 🧩 Prodotti config. › "Stampa abbigliamento (modello)".
-- =====================================================================

with m as (
  select modello_stampa_id as id from public.catalogo_fornitore_sync where fornitore = 'newwave'
)
update public.prodotti_config_stampe s
set prezzo_pz = v.prezzo_pz, setup = v.setup
from m, (values
  ('Lato cuore',          0.40, 10),
  ('Lato destro',         0.40, 10),
  ('Centro fronte',       0.50, 12),
  ('Centro retro',        0.50, 12),
  ('Manica sinistra',     0.40, 10),
  ('Manica destra',       0.40, 10),
  ('Centro collo fronte', 0.40, 10),
  ('Centro collo retro',  0.40, 10)
) as v(nome, prezzo_pz, setup)
where s.prodotto_id = m.id and s.nome = v.nome;

-- controllo (posizioni di v19; il RICAMO non è toccato da questo script)
select s.nome, s.prezzo_pz, s.setup, p.margine_pct, p.minimo
from public.prodotti_config_stampe s
join public.prodotti_config p on p.id = s.prodotto_id
where p.id = (select modello_stampa_id from public.catalogo_fornitore_sync where fornitore = 'newwave')
order by s.ordine;
