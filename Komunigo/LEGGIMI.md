# KOMUNIGO — e-commerce di Creatio Group

Negozio pubblico (`komunigo.it` / `.com`), **separato** dal gestionale interno ma sullo
**stesso database Supabase** (progetto `xejakgjjvlivhlxzqksa`): catalogo, magazzino e prezzi
arrivano dal "cervello" del gestionale — niente doppioni da sincronizzare.

## Stack (identico al gestionale)
HTML a file singolo + React 18 UMD + Babel standalone + supabase-js, con **tutte le librerie
in locale** in `lib/` (il firewall aziendale blocca i CDN). Nessun Node/npm per far girare il sito.

## Struttura
```
Komunigo/
├── index.html      negozio (Home, Catalogo stock+configurabili, Configuratore, Carrello)
├── config.js       stesso URL Supabase + chiave anon (PUBBLICA, sicura: protetta da RLS)
├── lib/            React, ReactDOM, Babel, supabase-js (locali)
├── compilecheck.js verifica JSX:  & "C:\Program Files\nodejs\node.exe" compilecheck.js
├── migrazioni/
│   └── komunigo-v1.sql   viste pubbliche + tabelle ordini (ADDITIVO, non tocca il gestionale)
└── supabase/functions/
    ├── prezzo-configuratore/index.ts   calcola il prezzo su misura (server, costi nascosti)
    └── ordine-pagato/index.ts          crea ordine + pagamento Nexi + automazione
```

## Come funziona l'aggancio al gestionale (sicurezza)
- Un visitatore **non loggato** (ruolo `anon`) **non legge nulla** del gestionale: le policy RLS
  richiedono un profilo approvato. Restiamo così.
- Il sito legge solo **viste `komunigo_*`** che espongono i **campi sicuri**:
  - `komunigo_prodotti` — articoli con flag **`vendibile=true`**: nome, descrizione, `prezzo_pubblico`,
    disponibilità = `giacenza − impegnato`, foto. **Mai** costo / prezzo riservato.
  - `komunigo_configuratori` (+ `_varianti`, `_voci`) — per comporre la scelta. **Mai** i costi:
    il **prezzo si calcola sul server** (Edge Function `prezzo-configuratore`).
- Gli **ordini** (`komunigo_ordini`) li scrive **solo il server** (Edge Function con service_role),
  non il browser → prezzi non falsificabili.

## Per far vedere il negozio funzionante — checklist
1. **Eseguire `migrazioni/komunigo-v1.sql`** in Supabase → SQL Editor → Run (crea le viste + tabelle).
2. Nel **gestionale**, mettere qualche articolo con **“vendibile” = sì**, prezzo pubblico e foto;
   e almeno un **Prodotto configurabile** attivo.
3. Aprire `index.html`: catalogo, carrello e configuratore (UI) funzionano subito.
4. Il **prezzo su misura** e il **pagamento** compaiono quando si fanno le 2 Edge Function.

## Cosa manca per chiudere la Fase 1 (in ordine)
- [ ] Edge Function **`prezzo-configuratore`**: portare la formula `calcolaConfigurato` dal gestionale.
- [ ] **Upload file grafico** nel configuratore (bucket Storage + check risoluzione).
- [ ] Edge Function **`ordine-pagato`** + **Nexi** (credenziali terminale come segreti) → redirect pagamento.
- [ ] **Webhook Nexi “pagato”** → impegno magazzino → commessa (su misura) / ordine neutri al fornitore
      + **alert al commerciale** (gadget).
- [ ] Email di conferma ordine (posta pro `info@komunigo.it`).

## Pubblicazione
Dominio pubblico **komunigo.it / .com**. Due strade (in entrambe l'utente digita komunigo.it):
- **Netlify** (consigliato, come il gestionale): repo GitHub dedicato → deploy automatico → dominio
  komunigo.it puntato a Netlify. Stesso workflow che il team già conosce.
- **Aruba via FTP**: caricare i file sull'hosting già pagato (aggiornamenti manuali).

## Fasi successive (dopo la Fase 1)
- **Fase 2** — Area clienti **B2B**: login, listini personali, riordino, stato commesse.
- **Fase 3** — Gadget/maglieria dal **magazzino fornitore** (dipende da feed/API dei fornitori;
  mail-tipo già pronta in `Documenti da Condividere/Mail-Fornitori-Giacenze.txt`). Non è dropshipping:
  Creatio compra il neutro e lo personalizza.

> Nota: il gestionale è in collaudo (go-live gennaio 2027). Komunigo si costruisce **in parallelo e con
> calma**, solo con migrazioni **additive** (`komunigo_*`) che non toccano tabelle/policy esistenti.
