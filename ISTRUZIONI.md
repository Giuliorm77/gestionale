# Gestionale · Stampa & Allestimenti

App web (HTML + React da CDN) collegata a un database cloud **Supabase**.
Nessuna installazione di programmi: bastano un browser e un account Supabase gratuito.

Primo modulo attivo: **Anagrafica Clienti** con **ruoli e permessi**.

---

## File del progetto

| File | Cosa contiene |
|------|---------------|
| `index.html` | L'applicazione (aprila nel browser) |
| `config.js` | Le chiavi del tuo progetto Supabase (da compilare) |
| `supabase-schema.sql` | Lo schema del database da eseguire una sola volta |
| `ISTRUZIONI.md` | Questo file |

---

## Configurazione (una volta sola, ~10 minuti)

### 1. Crea il database
1. Vai su **https://supabase.com** e registrati (piano gratuito).
2. **New project** → dai un nome (es. `gestionale`) e scegli una password del database.
3. Attendi 1-2 minuti che il progetto sia pronto.

### 2. Crea le tabelle
1. Menu a sinistra → **SQL Editor** → **New query**.
2. Apri `supabase-schema.sql`, copia **tutto** il contenuto, incollalo e premi **Run**.
3. Deve comparire *Success*.

### 3. Collega l'app
1. Menu a sinistra → **Settings** (ingranaggio) → **API**.
2. Copia **Project URL** e la chiave **anon public**.
3. Apri `config.js` e incollali al posto dei segnaposto:
   ```js
   window.GESTIONALE_CONFIG = {
     SUPABASE_URL: "https://xxxxx.supabase.co",
     SUPABASE_ANON_KEY: "eyJhbGciOi....."
   };
   ```

### 4. Crea il primo Amministratore
1. Apri `index.html` nel browser → schermata di login → **Registrati** con la tua email.
   - Se Supabase chiede la conferma via email, confermala (oppure disattiva la conferma in
     *Authentication → Providers → Email → "Confirm email" OFF* per andare più veloce in fase di test).
2. Torna nel **SQL Editor** di Supabase ed esegui, con la tua email:
   ```sql
   update public.profiles set ruolo = 'amministratore'
   where id = (select id from auth.users where email = 'tua@email.it');
   ```
3. Rientra nell'app: ora sei Amministratore e vedi anche la voce **Utenti & Ruoli**,
   da cui assegnare i ruoli a tutti gli altri (che intanto si registrano da soli).

---

## Ruoli e permessi

| Ruolo | Vede clienti | Crea/Modifica | Elimina | Dati fiscali | Dati economici (sconti) | Gestione utenti |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|
| **Amministratore** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Commerciale** | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| **Reception** | ✅ | ✅ (no elimina) | ❌ | ✅ | ❌ | ❌ |
| **Produzione** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

> **Sicurezza:** i permessi non sono solo nascosti nell'interfaccia — sono applicati dal
> database con le *Row Level Security policies*. I dati economici (sconti/listino) stanno in
> una tabella separata a cui Produzione e Reception non hanno proprio accesso.

---

## Uso quotidiano

- **Aprire l'app:** basta aprire `index.html`. Per usarla su più PC, mettila online gratis
  (es. trascina la cartella su **netlify.com/drop**, oppure GitHub Pages): tutti si collegano
  allo stesso database.
- **Cercare:** casella di ricerca (ragione sociale, attività, città, email) + filtro per lavorazione.
- **Nuovo cliente:** più **sedi** (legale / operativa / destinazione merce), più **email**
  categorizzate (amministrazione, commerciale, generica, PEC, ordini), telefono + cellulare,
  tipo attività libero, lavorazioni, e sconto (solo ruoli economici).

---

## Prossimi moduli (già predisposti nel menu)

1. **Listini** — l'aggancio è già pronto nella scheda cliente.
2. **Preventivi**
3. **Commesse / Produzione** con stati per reparto.

Il campo listino nella scheda cliente si collegherà automaticamente quando costruiremo il modulo Listini.
