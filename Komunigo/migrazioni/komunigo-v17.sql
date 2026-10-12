-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v17  (abbigliamento personalizzato sul negozio)
--
--  Mostra sul negozio i capi del CATALOGO FORNITORE (v16) spuntati "Proponi".
--  Il cliente sceglie colore, quantità PER TAGLIA e dove stampare.
--  Prezzo (calcolato SOLO dal server, edge hyper-endpoint + komunigo-ordine):
--    capo   = netto fornitore × (1 + ricarico%)   [ricarico dal modulo 🧵]
--    stampa = posizioni del "MODELLO DI STAMPA" (un prodotto config. tipo gadget
--             con solo_modello=true): prezzo_pz × colori × pezzi + impianto,
--             con il margine del modello; fasce sconto quantità del modello.
--
--  1) prodotti_config.solo_modello: i modelli di stampa NON compaiono come
--     prodotti nel negozio (vista komunigo_configuratori li esclude).
--  2) modello_stampa_id predefinito (per fornitore) e per singolo capo.
--  3) crea un modello "Stampa abbigliamento" di partenza con 4 posizioni
--     → PREZZI DI STAMPA DA RIVEDERE in 🧩 Prodotti config. prima di andare online.
--  4) viste PUBBLICHE senza costi: komunigo_abbigliamento, _colori, _taglie
--     (mai il prezzo netto: solo il prezzo di vendita del capo).
--
--  Richiede v16. Additiva. Da eseguire UNA VOLTA in Supabase -> SQL Editor -> Run.
--  Sicura da ri-eseguire (non duplica il modello).
-- =====================================================================

alter table public.prodotti_config add column if not exists solo_modello boolean not null default false;
alter table public.prodotti_config_stampe add column if not exists tecnica text not null default '';

-- vista pubblica dei configuratori: identica a v107 ma SENZA i modelli di stampa
drop view if exists public.komunigo_configuratori;
create view public.komunigo_configuratori as
select p.id, p.nome, p.unita_calcolo, p.minimo, p.note, p.tipo,
       nullif(p.categoria,'') as categoria, p.giorni_lavorazione,
       p.shop_mis_min, p.shop_mis_max, p.shop_quantita
from public.prodotti_config p
where p.attivo = true and coalesce(p.solo_modello,false) = false;
grant select on public.komunigo_configuratori to anon, authenticated;

alter table public.catalogo_fornitore_sync
  add column if not exists modello_stampa_id uuid references public.prodotti_config (id) on delete set null;
alter table public.catalogo_fornitore_prodotti
  add column if not exists modello_stampa_id uuid references public.prodotti_config (id) on delete set null;

-- modello di stampa di partenza (solo se non ce n'è già uno impostato)
do $$
declare v_id uuid;
begin
  if (select modello_stampa_id from public.catalogo_fornitore_sync where fornitore='newwave') is null then
    insert into public.prodotti_config (nome, unita_calcolo, tipo, categoria, margine_pct, minimo,
                                        giorni_lavorazione, attivo, solo_modello, note)
    values ('Stampa abbigliamento (modello)', 'pz', 'gadget', 'Abbigliamento', 40, 10, 10, true, true,
            'Modello di stampa per i capi del catalogo fornitore. PREZZI DI STAMPA DA RIVEDERE prima di andare online.')
    returning id into v_id;
    insert into public.prodotti_config_stampe (prodotto_id, nome, area_cm, max_colori, prezzo_pz, setup, tecnica, ordine) values
      (v_id, 'Petto lato cuore', '10 × 10', 4, 0.60, 25, 'Serigrafia', 0),
      (v_id, 'Fronte grande',    '30 × 40', 4, 1.20, 35, 'Serigrafia', 1),
      (v_id, 'Retro grande',     '30 × 40', 4, 1.20, 35, 'Serigrafia', 2),
      (v_id, 'Manica',           '8 × 8',   2, 0.60, 25, 'Serigrafia', 3);
    insert into public.prodotti_config_fasce (prodotto_id, da_quantita, sconto_pct, ordine) values
      (v_id, 50, 5, 0), (v_id, 100, 10, 1);
    update public.catalogo_fornitore_sync set modello_stampa_id = v_id where fornitore='newwave';
  end if;
end $$;

-- ---------------- VISTE PUBBLICHE (negozio) ----------------
-- girano come proprietario (bypassano la RLS staff delle tabelle v16) ma
-- espongono SOLO i capi proposti, attivi e con un modello di stampa.
drop view if exists public.komunigo_abbigliamento_taglie;
drop view if exists public.komunigo_abbigliamento_colori;
drop view if exists public.komunigo_abbigliamento;

create view public.komunigo_abbigliamento as
select p.fornitore, p.codice, p.nome, p.brand, catf.cat as sottocategoria, p.descrizione, p.linea, p.genere,
       p.vestibilita, p.tessuto, p.grammatura, p.taglie, p.lavaggio, p.immagini,
       m.id as modello_stampa_id, m.minimo, m.giorni_lavorazione,
       (select round(min(k.prezzo_netto) * (1 + coalesce(p.ricarico_pct, s.ricarico_default) / 100), 2)
          from public.catalogo_fornitore_sku k
         where k.fornitore=p.fornitore and k.codice_prodotto=p.codice and k.attivo and k.prezzo_netto > 0) as prezzo_da
from public.catalogo_fornitore_prodotti p
join public.catalogo_fornitore_sync s on s.fornitore = p.fornitore
join public.prodotti_config m on m.id = coalesce(p.modello_stampa_id, s.modello_stampa_id)
cross join lateral (select split_part(p.categoria, ';', array_length(string_to_array(p.categoria, ';'), 1)) as cat) catf
where p.selezionato and p.attivo;
grant select on public.komunigo_abbigliamento to anon, authenticated;

create view public.komunigo_abbigliamento_colori as
select v.fornitore, v.codice_prodotto, v.codice_colore, v.colore, v.immagini, v.ordine
from public.catalogo_fornitore_varianti v
join public.komunigo_abbigliamento a on a.fornitore = v.fornitore and a.codice = v.codice_prodotto
where v.attivo
  and exists (select 1 from public.catalogo_fornitore_sku k
               where k.fornitore=v.fornitore and k.codice_prodotto=v.codice_prodotto
                 and k.codice_colore=v.codice_colore and k.attivo and k.prezzo_netto > 0);
grant select on public.komunigo_abbigliamento_colori to anon, authenticated;

-- prezzo = prezzo di VENDITA del capo neutro (netto × ricarico), mai il netto
create view public.komunigo_abbigliamento_taglie as
select k.fornitore, k.codice_prodotto, k.codice_colore, k.sku, k.taglia, k.ordine,
       round(k.prezzo_netto * (1 + coalesce(p.ricarico_pct, s.ricarico_default) / 100), 2) as prezzo
from public.catalogo_fornitore_sku k
join public.catalogo_fornitore_prodotti p on p.fornitore = k.fornitore and p.codice = k.codice_prodotto
join public.catalogo_fornitore_sync s on s.fornitore = k.fornitore
where p.selezionato and p.attivo and k.attivo and k.prezzo_netto > 0
  and coalesce(p.modello_stampa_id, s.modello_stampa_id) is not null;
grant select on public.komunigo_abbigliamento_taglie to anon, authenticated;

-- Fine migrazione Komunigo v17.
-- (Per annullare: drop delle 3 viste komunigo_abbigliamento*, ripristinare la vista
--  komunigo_configuratori di v107, drop colonne modello_stampa_id / solo_modello.)
