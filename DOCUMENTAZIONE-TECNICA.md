# Gestionale Creatio — Documentazione tecnica

> Documento di riferimento del progetto. Serve a capire **com'è fatto** il gestionale
> e **come ci si mette mano**, anche per un tecnico che lo vede per la prima volta.
> Ultimo aggiornamento: **12 luglio 2026**.

---

## 1. Cos'è

Gestionale web per un'azienda di **stampa e allestimenti** (stampa digitale, serigrafia,
gadget, insegne luminose, cartotecnica, packaging).

Copre il ciclo operativo: **anagrafiche → preventivi → commesse → produzione → magazzino
→ ordini fornitori → consuntivo**, con un sistema di **permessi per ruolo** e reportistica.

- **Sito live:** https://gestionale-creatio.netlify.app
- **Obiettivo:** sostituire il gestionale attuale. Go-live previsto **gennaio 2027**
  (test da luglio 2026, con periodo di doppio binario).

---

## 2. Architettura (e perché è così)

Il progetto è volutamente **minimale**:

| Pezzo | Tecnologia | Note |
|---|---|---|
| Interfaccia | **Un unico file `index.html`** (~388 KB) | React 18 (UMD) + Babel standalone compilato **nel browser** |
| Librerie | cartella **`lib/`** (locali, non da CDN) | Il firewall aziendale blocca i CDN → le librerie stanno in locale |
| Backend/DB | **Supabase** (PostgreSQL) | Autenticazione, dati, permessi via RLS |
| Hosting | **Netlify** | Sito statico, HTTPS incluso |
| Pubblicazione | **GitHub → Netlify** (deploy automatico) | Push su `main` → il sito si aggiorna da solo |

**Perché un solo file HTML?** Semplicità e portabilità estrema: funziona anche aperto
da `file://`, non richiede build. **Prezzo da pagare:** Babel compila React a ogni
apertura (qualche secondo di avvio) e il file è grande. È una scelta consapevole,
ottima per pochi utenti; da rivedere (pre-compilazione) se il progetto cresce molto —
vedi §10.

### Configurazione — `config.js`
```js
window.GESTIONALE_CONFIG = {
  SUPABASE_URL: "https://xejakgjjvlivhlxzqksa.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_..."   // chiave PUBBLICA, sicura nel browser (protetta da RLS)
};
```
⚠️ La chiave `service_role` (segreta) **non deve MAI** stare qui né nel browser.

---

## 3. Struttura della cartella

Cartella progetto: `C:\Users\utente\OneDrive\Desktop\Gestionale2026`

| File / cartella | Cos'è | Pubblicabile? |
|---|---|---|
| `index.html` | **L'intera app** (sorgente di verità) | ✅ |
| `config.js` | URL Supabase + chiave anon pubblica | ✅ |
| `lib/` | React, ReactDOM, Babel, supabase-js, xlsx (locali) | ✅ |
| `SITO_DA_PUBBLICARE/` | **Copia** dei file pubblicabili + repo git di deploy | ✅ (è il deploy) |
| `migrazioni/` | Le migrazioni SQL (`supabase-schema.sql` → `v46.sql`) + `reset-dati.sql`, in ordine | ❌ (interne) |
| `compilecheck.js` | Verifica che il JSX compili (vedi §4) | ❌ |
| `RISERVATO-password/` | **PASSWORD** (`.odt`) — raccolte qui, fuori dal resto | ❌❌ MAI pubblicare |
| `CASSAFORTE/` | Copia di sicurezza ricostruibile del progetto (vedi `LEGGIMI.txt` dentro) | ❌ (privata) |
| `resoconto-conversazione.txt`, `database.odt`, `ISTRUZIONI.md` | Appunti storici | ❌ |

> Nota: solo `SITO_DA_PUBBLICARE/` finisce online. Tutto il resto (SQL, password,
> appunti) resta in locale e **non** è nel repository di deploy.

---

## 4. Come si lavora sul codice

1. Si modifica **`index.html`** (è tutto lì: HTML, CSS e i blocchi
   `<script type="text/babel">` con React).
2. **Verifica di compilazione** (obbligatoria dopo ogni modifica al JS), perché gli
   errori JSX nel browser sono muti:
   ```
   "C:\Program Files\nodejs\node.exe" compilecheck.js
   ```
   Node è installato ma **non è nel PATH** delle shell → va chiamato col percorso completo.
   Lo script estrae i blocchi babel e li passa a `Babel.transform` con lo **stesso**
   `lib/babel.min.js` e preset `react-classic` del browser: se compila qui, compila lì.
3. In sviluppo, dopo aver salvato, ricaricare la pagina con **Ctrl+Shift+R**
   (Firefox su `file://` ha una cache aggressiva).

---

## 5. Pubblicazione (deploy automatico)

- **Repository:** `github.com/Giuliorm77/gestionale-creatio` (privato)
- **Repo locale:** la cartella `SITO_DA_PUBBLICARE/` (git, remote `origin` = quello sopra)
- **Netlify** sorveglia il repo con **auto-publish ON**: ogni push su `main` ripubblica.

### Procedura di aggiornamento del sito
```bash
# 1. copiare il file aggiornato nella cartella di deploy
cp index.html SITO_DA_PUBBLICARE/index.html
# 2. salvare e pubblicare
git -C SITO_DA_PUBBLICARE add .
git -C SITO_DA_PUBBLICARE commit -m "descrizione modifica"
git -C SITO_DA_PUBBLICARE push origin main
# 3. Netlify ricostruisce da solo in ~1 minuto
```
In alternativa, senza git: trascinare la cartella `SITO_DA_PUBBLICARE` su
`app.netlify.com/drop`. Netlify tiene comunque lo **storico dei deploy** (rollback con un clic).

`config.js` e `lib/` cambiano di rado: normalmente si aggiorna solo `index.html`.

---

## 6. Database (Supabase)

- Progetto Supabase: `xejakgjjvlivhlxzqksa` (URL in `config.js`).
- **Migrazioni:** i file `supabase-schema*.sql` vanno eseguiti **in ordine** nel
  **SQL Editor** di Supabase (base → v2 → … → v46). Sono scritti per essere **sicuri
  da ri-eseguire** (`if not exists`, `create or replace`). L'ultima applicata è la **v46**.
- **Query di controllo "quali migrazioni sono applicate":** vedi le ultime v40–v46,
  si verificano con l'esistenza di colonne/tabelle (`information_schema`).
- `reset-dati.sql`: svuota le tabelle e re-inserisce i dati minimi (9 lavorazioni +
  riga impostazioni). **Solo in fase di test.**

### Sicurezza a livello database (RLS)
- Funzione `ruolo_utente()` → restituisce il ruolo dell'utente loggato (null se non
  approvato). È la base di quasi tutte le policy.
- Funzione `puo_economici()` (v46) → true se l'utente può vedere costi/prezzi/margini.
- Le tabelle **interamente economiche** (preventivi, listini, tariffe lavorazioni,
  ordini fornitore, corrieri, interventi, condizioni/listini clienti) sono **blindate**:
  chi non ha l'economico riceve **vuoto**, non solo nascosto graficamente.

---

## 7. Permessi e ruoli

Definiti nel codice (oggetto `PERMESSI`) e applicati anche dal DB.

| Ruolo | Economico | Scrive | Elimina | Gestione utenti |
|---|:---:|:---:|:---:|:---:|
| `amministratore` | ✅ | ✅ | ✅ | ✅ |
| `commerciale` | ✅ | ✅ | ❌ | ❌ |
| `produzione` | ❌ | ❌ | ❌ | ❌ |
| `reception` | ❌ (ma fiscali sì) | ✅ | ❌ | ❌ |

- **Deroghe per singolo utente:** campo `profiles.permessi` (jsonb) → si gestiscono dal
  modulo **🔑 Utenti & Ruoli** (pulsante *Permessi*, stati "Come ruolo / Sì / No").
- **Flusso utenti:** ognuno si registra da solo → l'amministratore **approva** e
  assegna il ruolo. Gli account **non** si eliminano dall'app (serve la chiave admin di
  Supabase): si **sospendono**, oppure si cancellano dal pannello Supabase → Authentication.
- **Convenzione decisa:** la postazione "Amministrazione" (poteri < titolari) = ruolo
  `commerciale` + deroga *Impostazioni = No*. Non si è creato un ruolo nuovo perché le
  policy RLS autorizzano solo `amministratore`/`commerciale` a scrivere.

---

## 8. Backup (doppio)

1. **PC** — `C:\Users\utente\GestionaleBackup\backup-gestionale.ps1`, lanciato da Task
   Scheduler alle **13:00 e 18:00**. Usa `-UserAgent "GestionaleBackup/1.0"` (le chiavi
   segrete sono bloccate sulle richieste "da browser").
   🔐 **Sicurezza chiave (sistemato 12/07/2026):** la chiave `service_role` **non è più
   nel file**. È cifrata con DPAPI (legata all'utente `utente` e a questo PC) nel file
   `C:\Users\utente\GestionaleBackup\service_key.dat`; lo script la legge e decifra al volo.
   Il task "Backup Gestionale" gira come utente `utente` (interactive) → la decifratura funziona.
   Se un domani ricostruisci il backup su un **altro PC/utente**, va rigenerato `service_key.dat`
   dalla chiave conservata nel gestore password (ri-eseguendo la cifratura). Il `.dat` è inutile
   altrove (specifico di macchina+utente) e **non** va nei repository né in cassaforte.
2. **Cloud** — GitHub Actions, repo `gestionale-backup`, workflow `.github/workflows/backup.yml`.
   Gira **13:00 e 22:00** (copre la sera a PC spento). Scarica tutte le tabelle via API
   REST e le committa nel repo.
   - ⚠️ **Lezione appresa:** il workflow deve passare i dati **tramite file**, non come
     argomenti dei comandi: la carta intestata (immagine in base64 nella tabella
     `impostazioni`) supera il limite di lunghezza degli argomenti di Linux → errore
     "Argument list too long" / exit 126. Risolto il 12/07/2026.

**Ripristino:** i backup sono JSON per-tabella. Prima del go-live va fatta almeno una
**prova reale di ripristino** (non basta avere i backup).

---

## 9. Cosa manca / roadmap

Dettaglio completo nei due documenti-guida (artifact):
- **Guida messa in produzione:** https://claude.ai/code/artifact/c7f38b38-8b8d-4297-a5f6-45037effe292
- **Integrazione Fatture in Cloud:** https://claude.ai/code/artifact/ed61dc5f-74de-4c72-853c-89688d224154

In breve, per sostituire del tutto il vecchio gestionale servono:
1. **DDT**, **Fatturazione elettronica**, **Scadenzario** → tramite **integrazione con
   Fatture in Cloud** (API v2). Non si ricostruisce lo SDI: si crea il documento via API
   e Fatture in Cloud lo invia/conserva. Serve una **Supabase Edge Function** per tenere
   il token fuori dal browser.
2. **Messa in produzione seria:** Supabase Pro (~25 $/mese, no pause + backup/PITR + SMTP),
   dominio `gestionale.creatiogroup.it`, 2FA su Supabase e Netlify.
3. **Go-live gennaio 2027:** import dati reali, doppio binario 2–4 settimane, formazione,
   switch, vecchio gestionale in archivio (non buttato).

**Filone futuro:** e-commerce collegato (stesso database Supabase, catalogo già presente)
+ campagna marketing.

---

## 10. Debito tecnico da tenere d'occhio (non urgente)

- **Babel nel browser** → un domani si può **pre-compilare** il JSX per avvii istantanei.
- **File unico da 388 KB** → se cresce molto, valutare di **spezzarlo** in più file.
- **Continuità:** il progetto è cresciuto molto in fretta; questa documentazione serve
  proprio a non dipendere dalla memoria di una sola persona.

---

## 11. Riferimenti rapidi

| Cosa | Dove |
|---|---|
| Sito live | https://gestionale-creatio.netlify.app |
| Repo deploy | github.com/Giuliorm77/gestionale-creatio (privato) |
| Repo backup cloud | github.com/Giuliorm77/gestionale-backup |
| Supabase | progetto `xejakgjjvlivhlxzqksa` |
| Backup PC | `C:\Users\utente\GestionaleBackup\` |
| Node (per compilecheck) | `C:\Program Files\nodejs\node.exe` |
| Email azienda | info@creatiogroup.it |

---

*Documento da aggiornare a ogni cambiamento strutturale e da "congelare" nella versione
definitiva al go-live (vedi §12 del piano: snapshot del 31 dicembre 2026).*
