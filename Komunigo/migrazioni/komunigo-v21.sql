-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v21  (tracciato fustella scaricabile dal negozio)
--
--  Il negozio genera il tracciato PDF della scatola nel browser: gli serve
--  sapere il MODELLO (astuccio / fondo_automatico / fondo_coperchio /
--  americana). Lo espone nella vista pubblica komunigo_configuratori come
--  colonna "scatola_modello" (solo il nome del modello: nessun costo).
--  Vista identica alla v17 + la nuova colonna.
--  Supabase -> SQL Editor -> Run. Sicura da rieseguire.
-- =====================================================================

drop view if exists public.komunigo_configuratori;
create view public.komunigo_configuratori as
select p.id, p.nome, p.unita_calcolo, p.minimo, p.note, p.tipo,
       nullif(p.categoria,'') as categoria, p.giorni_lavorazione,
       p.shop_mis_min, p.shop_mis_max, p.shop_quantita,
       p.scatola->>'modello' as scatola_modello
from public.prodotti_config p
where p.attivo = true and coalesce(p.solo_modello,false) = false;
grant select on public.komunigo_configuratori to anon, authenticated;

-- controllo
select nome, tipo, scatola_modello from public.komunigo_configuratori where tipo = 'scatola' order by nome;

-- Fine migrazione Komunigo v21.
