-- =====================================================================
--  KOMUNIGO - MIGRAZIONE v20  (configuratore SCATOLE stile Pack.ly)
--
--  Nuovo tipo prodotto 'scatola': il cliente sceglie il MODELLO e scrive le
--  misure interne A×B×H (mm). Il server calcola il FOGLIO STESO del modello,
--  quante pose entrano nel foglio del materiale, i fogli, la stampa UV a m²,
--  il taglio (plotter o fustella: sceglie il più economico), l'incollaggio.
--  Le scatole sono prodotte IN CASA da Creatio:
--   - stampa UV digitale a fogli, max 250×150 cm
--   - taglio a plotter max 300×200 cm, oppure fustella max 120×160 cm
--
--  Riuso dei campi esistenti:
--   prodotti_config: margine_pct, minimo, shop_quantita (scaglioni mostrati),
--     stampa_margine_mm (margine foglio), stampa_prezzo_mq (UV €/m² per lato),
--     stampa_avviamento (avviamento stampa)
--   prodotti_config_varianti = MATERIALI: nome, spessore (mm), foglio_l_cm,
--     foglio_h_cm, costo_materiale (€/foglio), sfrido_pct
--  Nuovo: prodotti_config.scatola jsonb = parametri del modello e del taglio.
--
--  ⚠ I 4 prodotti creati qui hanno COSTI FINTI (da sostituire con i reali in
--  🧩 Prodotti config.). Additiva. Supabase -> SQL Editor -> Run. Rieseguibile.
-- =====================================================================

-- 1) tipo 'scatola' ammesso
do $$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.prodotti_config'::regclass and contype='c'
     and pg_get_constraintdef(oid) ilike '%tipo%';
  if c is not null then execute 'alter table public.prodotti_config drop constraint '||quote_ident(c); end if;
end $$;
alter table public.prodotti_config
  add constraint prodotti_config_tipo_check check (tipo in ('misura','gadget','stampa','scatola'));

-- 2) parametri scatola
-- {"modello":"astuccio|fondo_automatico|fondo_coperchio|americana",
--  "plotter_foglio":€, "fustella_costo":€ (una tantum per tracciato), "fustella_foglio":€,
--  "fustella_max_l_cm":120, "fustella_max_h_cm":160, "incollaggio_pz":€, "avviamento":€,
--  "distanza_mm":5}
alter table public.prodotti_config add column if not exists scatola jsonb;

-- 3) i 4 modelli di partenza (COSTI FINTI)
do $$
declare v uuid; r record;
begin
  for r in select * from (values
    ('Astuccio con alette a incastro', 'astuccio',         'Astucci in cartoncino', 0.06::numeric, 'gc1'),
    ('Astuccio con fondo automatico',  'fondo_automatico', 'Astucci in cartoncino', 0.10::numeric, 'gc1'),
    ('Scatola fondo e coperchio',      'fondo_coperchio',  'Scatole rivestite',     0.15::numeric, 'gc1'),
    ('Scatola americana',              'americana',        'Scatole in microonda',  0.08::numeric, 'onda')
  ) as t(nome, modello, categoria, incoll, mat)
  loop
    if not exists (select 1 from public.prodotti_config where nome = r.nome and tipo = 'scatola') then
      insert into public.prodotti_config (nome, tipo, unita_calcolo, categoria, margine_pct, minimo, attivo,
          giorni_lavorazione, stampa_margine_mm, stampa_prezzo_mq, stampa_avviamento, shop_quantita, scatola, note)
      values (r.nome, 'scatola', 'pz', r.categoria, 40, 0, true, 7, 10, 5.00, 25,
          '[100,250,500,1000,2500,5000]'::jsonb,
          jsonb_build_object('modello', r.modello, 'plotter_foglio', 3.50, 'fustella_costo', 150,
            'fustella_foglio', 0.40, 'fustella_max_l_cm', 120, 'fustella_max_h_cm', 160,
            'incollaggio_pz', r.incoll, 'avviamento', 20, 'distanza_mm', 5),
          'COSTI FINTI da sostituire (materiale, stampa, taglio, incollaggio).')
      returning id into v;
      if r.mat = 'gc1' then
        insert into public.prodotti_config_varianti (prodotto_id, nome, spessore, costo_materiale, sfrido_pct, foglio_l_cm, foglio_h_cm, ordine)
        values (v, 'Cartoncino GC1 350 g', 0.5, 0.80, 5, 70, 100, 0);
      else
        insert into public.prodotti_config_varianti (prodotto_id, nome, spessore, costo_materiale, sfrido_pct, foglio_l_cm, foglio_h_cm, ordine) values
          (v, 'Microonda onda E', 1.5, 2.20, 5, 120, 160, 0),
          (v, 'Microonda onda B', 3.0, 2.60, 5, 120, 160, 1);
      end if;
    end if;
  end loop;
end $$;

-- controllo
select p.nome, p.categoria, p.scatola->>'modello' as modello, string_agg(v.nome, ', ') as materiali
from public.prodotti_config p left join public.prodotti_config_varianti v on v.prodotto_id = p.id
where p.tipo = 'scatola' group by p.nome, p.categoria, p.scatola order by p.nome;

-- Fine migrazione Komunigo v20.
