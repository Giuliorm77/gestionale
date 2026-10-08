// =====================================================================
//  Edge Function: komunigo-ordine   (UNICA, con azioni)
//  Gestisce ordini e-commerce + upload file grafici del cliente.
//  Legge/scrive coi diritti service_role (prezzi ri-validati lato server,
//  costi mai esposti). Il cliente opera senza login tramite un TOKEN.
//
//  Deploy (dashboard): Edge Functions -> Deploy a new function ->
//     nome ESATTO: komunigo-ordine ; Verify JWT: OFF.
//
//  Azioni (POST body { action, ... }):
//   - "crea"          {cliente:{nome,email,tel}, spedizione_id, indirizzo, note, righe:[...]}
//                      -> ri-valida prezzi, crea ordine+righe -> {numero, token}
//   - "dettaglio"     {token} -> {ordine, righe, file[] con url di download firmati}
//   - "file-url"      {token, riga_id, nome_file} -> {bucket, path, token}  (per uploadToSignedUrl)
//   - "file-registra" {token, riga_id, path, nome_file, dimensione, mime} -> {ok, id}
//   - "file-elimina"  {token, file_id} -> {ok}
// =====================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const BUCKET = "komunigo-ordini";
const IVA = 0.22;
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, "Content-Type": "application/json" } });

// ---- SCONTO B2B (cliente loggato) --------------------------------------
// Stessa logica del gestionale (scontoPerCategoria): eccezione per categoria
// -> sconto standard cliente -> sconto rivenditori. Attivo solo se l'account
// e' su stato 'b2b' e collegato a un cliente in anagrafica.
const clampPct = (n: any) => { n = Number(n) || 0; return n < 0 ? 0 : n > 100 ? 100 : n; };
function scForCat(profilo: any, categoria: string): number {
  if (!profilo || !profilo.b2b) return 0;
  const cat = String(categoria || "").trim().toLowerCase();
  if (cat) {
    const e = (profilo.sconti_cat || []).find((x: any) => String(x.categoria || "").trim().toLowerCase() === cat);
    if (e && e.sconto_pct != null && e.sconto_pct !== "") return clampPct(e.sconto_pct);
  }
  if (profilo.sconto_std != null && profilo.sconto_std !== "") return clampPct(profilo.sconto_std);
  if ((profilo.cliente_categoria || "") === "Rivenditore") return clampPct(profilo.sconto_riv_std);
  return 0;
}
async function caricaProfiloB2b(admin: any, authH: string | null) {
  try {
    const t = (authH || "").replace("Bearer ", "").trim();
    if (!t) return { b2b: false };
    const { data: u } = await admin.auth.getUser(t);
    const uid = u?.user?.id;
    if (!uid) return { b2b: false };
    const { data: acc } = await admin.from("komunigo_account").select("stato,cliente_id").eq("id", uid).maybeSingle();
    if (!acc || acc.stato !== "b2b" || !acc.cliente_id) return { b2b: false };
    const { data: cli } = await admin.from("clienti").select("ragione_sociale,sconto_pct,categoria").eq("id", acc.cliente_id).maybeSingle();
    if (!cli) return { b2b: false };
    const { data: ecc } = await admin.from("clienti_sconti").select("categoria,sconto_pct").eq("cliente_id", acc.cliente_id);
    let scontoRiv = 0;
    if ((cli.categoria || "") === "Rivenditore") {
      const { data: imp } = await admin.from("impostazioni").select("sconto_rivenditori_pct").eq("id", 1).maybeSingle();
      scontoRiv = Number(imp?.sconto_rivenditori_pct) || 0;
    }
    return { b2b: true, sconto_std: cli.sconto_pct, sconti_cat: ecc || [], cliente_categoria: cli.categoria || "", sconto_riv_std: scontoRiv, cliente_nome: cli.ragione_sociale || "" };
  } catch (_) { return { b2b: false }; }
}

// ---- STAMPA SU CARTA (nesting a fogli) — replica di calcolaStampaFoglio ----
const FORMATI_STAMPA = [{ nome: "32×44", l: 32, h: 44 }, { nome: "33×48,8", l: 33, h: 48.8 }];
function poseIn(bw: number, bh: number, aw: number, ah: number) {
  if (aw <= 0 || ah <= 0 || bw <= 0 || bh <= 0) return 0;
  return Math.max(Math.floor(bw / aw) * Math.floor(bh / ah), Math.floor(bw / ah) * Math.floor(bh / aw));
}
function calcStampa(prod: any, va: any, L: number, H: number, N: number, opts: any, costoMat: number) {
  const vivo = (Number(prod.stampa_vivo_mm) || 0) / 10, marg = (Number(prod.stampa_margine_mm) || 0) / 10;
  const fw = L + 2 * vivo, fh = H + 2 * vivo;
  const sw = Number(va.foglio_l_cm) || 0, sh = Number(va.foglio_h_cm) || 0;
  const grande = opts.macchina === "grande";
  let perStock: number, pose: number;
  if (grande) { perStock = 1; pose = poseIn(sw - 2 * marg, sh - 2 * marg, fw, fh); }
  else {
    const cand = FORMATI_STAMPA.map((F) => {
      const ps = poseIn(F.l - 2 * marg, F.h - 2 * marg, fw, fh);
      const pst = poseIn(sw, sh, F.l, F.h);
      return { F, pose: ps, perStock: pst, pezziStock: ps * Math.max(1, pst) };
    });
    let selc = (opts.fmt && opts.fmt !== "auto") ? cand.find((c) => c.F.nome === opts.fmt) : null;
    if (!selc) selc = cand.slice().sort((a, b) => b.pezziStock - a.pezziStock)[0];
    pose = selc.pose; perStock = Math.max(1, selc.perStock);
  }
  const fogliMacchina = pose > 0 ? Math.ceil(N / pose) : 0;
  const fogliAcq = perStock > 0 ? Math.ceil(fogliMacchina / perStock) : fogliMacchina;
  const costoCarta = fogliAcq * costoMat * (1 + (Number(va.sfrido_pct) || 0) / 100);
  let costoStampa = 0;
  if (grande) { const mq = (L / 100) * (H / 100) * N; costoStampa = mq * (Number(prod.stampa_prezzo_mq) || 0); }
  else {
    const pass = opts.fr ? 2 : 1;
    const pp = opts.colore ? (Number(prod.stampa_prezzo_colore) || 0) : (Number(prod.stampa_prezzo_bn) || 0);
    costoStampa = fogliMacchina * pass * pp + (Number(prod.stampa_avviamento) || 0);
  }
  return costoCarta + costoStampa;
}

// ---- ricalcolo prezzo di un configurabile (replica di calcolaConfigurato) ----
async function prezzoConfigurabile(admin: any, prodotto_id: string, config: any) {
  const { data: prod, error } = await admin
    .from("prodotti_config")
    .select("*, prodotti_config_varianti(*), prodotti_config_voci(*), prodotti_config_fasce(*), prodotti_config_stampe(*)")
    .eq("id", prodotto_id).single();
  if (error || !prod) throw new Error("Prodotto configurabile non trovato");

  const { data: imp } = await admin.from("impostazioni").select("abbondanza_cm").limit(1).maybeSingle();
  const abb = Number(imp?.abbondanza_cm) || 0;

  const varr = prod.prodotti_config_varianti || [];
  const va = varr.find((v: any) => v.id === config?.variante_id) || varr[0] || { costo_materiale: 0, sfrido_pct: 0, spessore: 0 };

  let costoMat = Number(va.costo_materiale) || 0;
  if (va.articolo_id) {
    const { data: a } = await admin.from("articoli").select("costo").eq("id", va.articolo_id).maybeSingle();
    if (a && a.costo != null) costoMat = Number(a.costo) || 0;
  }

  const N = Number(config?.quantita) || 0;

  // ---- GADGET: variante colore + posizioni di stampa ----
  if (prod.tipo === "gadget") {
    const r2 = (x: number) => Math.round(x * 100) / 100;
    const costoBase = costoMat * N * (1 + (Number(va.sfrido_pct) || 0) / 100);
    const allSt = prod.prodotti_config_stampe || [];
    const scelte = Array.isArray(config?.stampe) ? config.stampe : [];
    const stCost: any[] = [];
    let costoSetup = 0;
    for (const scc of scelte) {
      const st = allSt.find((x: any) => x.id === scc.stampa_id);
      if (!st) continue;
      const colori = Math.max(1, Math.min(Number(scc.colori) || 1, Number(st.max_colori) || 4));
      stCost.push((Number(st.prezzo_pz) || 0) * colori * N);
      costoSetup += Number(st.setup) || 0;
    }
    const costo = costoBase + stCost.reduce((s, x) => s + x, 0) + costoSetup;
    const mg = Number(prod.margine_pct) || 0;
    const mFactor = mg > 0 ? 1 / (1 - mg / 100) : 1;
    const fasceG = (prod.prodotti_config_fasce || []).slice()
      .sort((a: any, b: any) => (Number(b.da_quantita) || 0) - (Number(a.da_quantita) || 0));
    const faG = fasceG.find((x: any) => N >= (Number(x.da_quantita) || 0));
    const factor = mFactor * (faG ? (1 - (Number(faG.sconto_pct) || 0) / 100) : 1);
    const totG = r2(r2(costoBase * factor) + stCost.reduce((s, x) => s + r2(x * factor), 0) + r2(costoSetup * factor));
    return { prezzo_unitario: N > 0 ? r2(totG / N) : totG, prezzo_totale: totG, sotto_costo: totG < r2(costo), costo_totale: r2(costo), categoria: prod.categoria || "", nome: prod.nome, quantita: N, unita_calcolo: "pz" };
  }

  // ---- STAMPA SU CARTA (nesting a fogli) ----
  if (prod.tipo === "stampa") {
    const r2 = (x: number) => Math.round(x * 100) / 100;
    const Ls = Number(config?.larghezza_cm) || 0, Hs = Number(config?.altezza_cm) || 0;
    const opts = { macchina: config?.st_macchina || "piccolo", fr: !!config?.st_fr, colore: !!config?.st_colore, fmt: config?.st_fmt || "auto" };
    let costoS = calcStampa(prod, va, Ls, Hs, N, opts, costoMat);
    const selS = new Set(Array.isArray(config?.opzioni) ? config.opzioni : []);
    (prod.prodotti_config_voci || []).forEach((voce: any) => {
      if (voce.opzionale && !selS.has(voce.id)) return;
      let qty = 0;
      if (voce.modo === "pz") qty = N; else if (voce.modo === "fisso") qty = 1;
      else if (voce.modo === "mq") qty = (Ls / 100) * (Hs / 100) * N;
      costoS += (Number(voce.costo) || 0) * qty;
    });
    const mg = Number(prod.margine_pct) || 0;
    let pr = mg > 0 ? costoS / (1 - mg / 100) : costoS;
    const fasceS = (prod.prodotti_config_fasce || []).slice().sort((a: any, b: any) => (Number(b.da_quantita) || 0) - (Number(a.da_quantita) || 0));
    const faS = fasceS.find((x: any) => N >= (Number(x.da_quantita) || 0));
    if (faS) pr = pr * (1 - (Number(faS.sconto_pct) || 0) / 100);
    if (Number(prod.minimo) > 0 && pr < Number(prod.minimo)) pr = Number(prod.minimo);
    const tot = r2(pr);
    return { prezzo_unitario: N > 0 ? r2(tot / N) : tot, prezzo_totale: tot, sotto_costo: tot < r2(costoS), costo_totale: r2(costoS), categoria: prod.categoria || "", nome: prod.nome, quantita: N, unita_calcolo: "pz" };
  }

  const sel = new Set(Array.isArray(config?.opzioni) ? config.opzioni : []);
  const u = prod.unita_calcolo;
  const L = Number(config?.larghezza_cm) || 0, H = Number(config?.altezza_cm) || 0, sp = Number(va.spessore) || 0;
  const Lm = L > 0 ? L + abb : 0, Hm = H > 0 ? H + abb : 0;
  let basePezzo = 1;
  if (u === "mq") basePezzo = (Lm / 100) * (Hm / 100);
  else if (u === "mtl") basePezzo = (Lm / 100);
  else if (u === "mc") basePezzo = (Lm / 100) * (Hm / 100) * (sp / 1000);
  const baseTot = basePezzo * N;

  let costo = costoMat * baseTot * (1 + (Number(va.sfrido_pct) || 0) / 100);
  (prod.prodotti_config_voci || []).forEach((voce: any) => {
    if (voce.opzionale && !sel.has(voce.id)) return;
    let qty = 0;
    if (voce.modo === u) qty = baseTot;
    else if (voce.modo === "fisso") qty = 1;
    costo += (Number(voce.costo) || 0) * qty;
  });

  const m = Number(prod.margine_pct) || 0;
  let prezzo = m > 0 ? costo / (1 - m / 100) : costo;
  const fasce = (prod.prodotti_config_fasce || []).slice()
    .sort((a: any, b: any) => (Number(b.da_quantita) || 0) - (Number(a.da_quantita) || 0));
  const fa = fasce.find((x: any) => N >= (Number(x.da_quantita) || 0));
  if (fa) prezzo = prezzo * (1 - (Number(fa.sconto_pct) || 0) / 100);
  if (Number(prod.minimo) > 0 && prezzo < Number(prod.minimo)) prezzo = Number(prod.minimo);

  const prezzo_totale = Math.round(prezzo * 100) / 100;
  const costo_totale = Math.round(costo * 100) / 100;
  const prezzo_unitario = N > 0 ? Math.round((prezzo / N) * 100) / 100 : prezzo_totale;
  return { prezzo_unitario, prezzo_totale, sotto_costo: prezzo_totale < costo_totale, costo_totale, categoria: prod.categoria || "", nome: prod.nome, quantita: N, unita_calcolo: u };
}

const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
async function ordineDaToken(admin: any, token: string) {
  if (!token || !uuidRe.test(token)) throw new Error("Token non valido");
  const { data, error } = await admin.from("komunigo_ordini").select("*").eq("token", token).maybeSingle();
  if (error || !data) throw new Error("Ordine non trovato");
  return data;
}
const safeName = (s: string) => String(s || "file").replace(/[^\w.\-]+/g, "_").slice(-80);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const body = await req.json().catch(() => ({}));
    const action = body?.action;

    // -------------------------------------------------------- PROFILO PREZZI
    // Restituisce al cliente loggato il PROPRIO profilo sconti B2B, così il
    // negozio può mostrare i prezzi riservati sui prodotti a magazzino.
    // (Sono i dati del cliente stesso: nessun costo, nessun dato di altri.)
    if (action === "profilo-prezzi") {
      const prof = await caricaProfiloB2b(admin, req.headers.get("Authorization"));
      return json(prof);
    }

    // ---------------------------------------------------- ELIMINA ACCOUNT (staff)
    // Rimuove un cliente del negozio: accesso (auth) + riga komunigo_account.
    // Gli ordini restano (account_id -> null). L'anagrafica cliente NON si tocca.
    if (action === "account-elimina") {
      const authE = (req.headers.get("Authorization") || "").replace("Bearer ", "").trim();
      let uid: string | null = null;
      if (authE) { try { const { data: u } = await admin.auth.getUser(authE); uid = u?.user?.id || null; } catch (_) { /* */ } }
      if (!uid) return json({ error: "Non autenticato" }, 401);
      const { data: prof } = await admin.from("profiles").select("ruolo").eq("id", uid).maybeSingle();
      if (!prof || !["amministratore", "commerciale"].includes(prof.ruolo)) return json({ error: "Non autorizzato" }, 403);
      const target = String(body.account_id || "");
      if (!uuidRe.test(target)) return json({ error: "account_id non valido" }, 400);
      const { data: acc } = await admin.from("komunigo_account").select("id").eq("id", target).maybeSingle();
      if (!acc) return json({ error: "Account non trovato" }, 404);
      await admin.from("komunigo_ordini").update({ account_id: null }).eq("account_id", target);
      await admin.from("komunigo_account").delete().eq("id", target);
      try { await admin.auth.admin.deleteUser(target); } catch (_) { /* utente auth già assente: ok */ }
      return json({ ok: true });
    }

    // ---------------------------------------------------------------- CREA
    if (action === "crea") {
      const righeIn = Array.isArray(body.righe) ? body.righe : [];
      if (!righeIn.length) return json({ error: "Carrello vuoto" }, 400);

      // se il cliente è loggato, colleghiamo l'ordine al suo account
      let accountId: string | null = null;
      const authH = (req.headers.get("Authorization") || "").replace("Bearer ", "").trim();
      if (authH) { try { const { data: u } = await admin.auth.getUser(authH); accountId = u?.user?.id || null; } catch (_) { /* ospite */ } }
      // profilo sconti del cliente loggato (0 se ospite o non B2B)
      const profB2b = await caricaProfiloB2b(admin, req.headers.get("Authorization"));
      // dati pagamento differito (conto aperto) dell'account, se loggato
      let acct: any = null;
      if (accountId) { const { data } = await admin.from("komunigo_account").select("pagamento_differito,giorni_pagamento").eq("id", accountId).maybeSingle(); acct = data; }

      const righe: any[] = [];
      let imponibileMerce = 0;
      for (const r of righeIn) {
        if (r.tipo === "configurabile") {
          const cfg = { ...(r.config || {}), quantita: (r.config?.quantita ?? r.quantita) };
          const p = await prezzoConfigurabile(admin, r.prodotto_config_id, cfg);
          const s = scForCat(profB2b, p.categoria);
          const netTot = s > 0 ? Math.round(p.prezzo_totale * (1 - s / 100) * 100) / 100 : p.prezzo_totale;
          const netUnit = p.quantita > 0 ? Math.round((netTot / p.quantita) * 100) / 100 : netTot;
          if (!(netTot > 0) || netTot < p.costo_totale) throw new Error(`Prezzo non valido per "${p.nome}"`);
          righe.push({
            tipo: "configurabile", prodotto_config_id: r.prodotto_config_id,
            descrizione: r.descrizione || p.nome, config: r.config || {},
            quantita: p.quantita, prezzo_unitario: netUnit, prezzo_totale: netTot,
          });
          imponibileMerce += netTot;
        } else {
          const { data: a } = await admin.from("articoli")
            .select("id,nome_articolo,categoria,prezzo_pubblico,vendibile,giacenza,impegnato").eq("id", r.articolo_id).maybeSingle();
          if (!a || a.vendibile !== true) throw new Error("Prodotto non disponibile");
          const disp = Math.max((Number(a.giacenza) || 0) - (Number(a.impegnato) || 0), 0);
          const qta = Math.max(1, Math.min(Number(r.quantita) || 1, disp || 1));
          const s = scForCat(profB2b, a.categoria);
          const puList = Number(a.prezzo_pubblico) || 0;
          const pu = s > 0 ? Math.round(puList * (1 - s / 100) * 100) / 100 : puList;
          const tot = Math.round(pu * qta * 100) / 100;
          righe.push({
            tipo: "prodotto", articolo_id: a.id, descrizione: a.nome_articolo,
            config: {}, quantita: qta, prezzo_unitario: pu, prezzo_totale: tot,
          });
          imponibileMerce += tot;
        }
      }

      // spedizione (ri-validata sul catalogo opzioni)
      let sped: any = null, spedCosto = 0;
      if (body.spedizione_id) {
        const { data: s } = await admin.from("komunigo_spedizioni")
          .select("id,nome,prezzo,ritiro,attivo").eq("id", body.spedizione_id).maybeSingle();
        if (s && s.attivo) { sped = s; spedCosto = Number(s.prezzo) || 0; }
      }

      const imponibile = Math.round((imponibileMerce + spedCosto) * 100) / 100;
      const iva = Math.round(imponibile * IVA * 100) / 100;
      const totale = Math.round((imponibile + iva) * 100) / 100;

      const yr = new Date().getFullYear();
      const { count } = await admin.from("komunigo_ordini")
        .select("*", { count: "exact", head: true }).like("numero", `K-${yr}-%`);
      const numero = `K-${yr}-${String((count || 0) + 1).padStart(4, "0")}`;

      // pagamento: il "differito" (conto aperto) è ammesso solo se l'account lo ha abilitato
      let pagMetodo = body.pagamento_metodo || null;
      let pagStato = "in_attesa";
      let pagGiorni: number | null = null;
      if (pagMetodo === "differito") {
        if (!acct || acct.pagamento_differito !== true) throw new Error("Pagamento differito non abilitato per questo account");
        pagStato = "differito";
        pagGiorni = Number(acct.giorni_pagamento) || 30;
      }

      const cliente = body.cliente || {};
      const { data: ord, error: eOrd } = await admin.from("komunigo_ordini").insert({
        numero, stato: "nuovo",
        cliente_nome: cliente.nome || "", cliente_email: cliente.email || "", cliente_tel: cliente.tel || "",
        spedizione: { opzione: sped ? { id: sped.id, nome: sped.nome, prezzo: spedCosto, ritiro: !!sped.ritiro } : null, indirizzo: body.indirizzo || null },
        pagamento_metodo: pagMetodo, pagamento_stato: pagStato, pagamento_giorni: pagGiorni,
        account_id: accountId,
        imponibile, iva, totale, note: body.note || "",
      }).select("id, numero, token").single();
      if (eOrd || !ord) throw new Error(eOrd?.message || "Creazione ordine fallita");

      const righeDb = righe.map((x, i) => ({ ...x, ordine_id: ord.id, ordine: i }));
      const { error: eR } = await admin.from("komunigo_ordini_righe").insert(righeDb);
      if (eR) throw new Error(eR.message);

      return json({ ok: true, numero: ord.numero, token: ord.token, totale });
    }

    // ------------------------------------------------------------ DETTAGLIO
    if (action === "dettaglio") {
      const ord = await ordineDaToken(admin, body.token);
      const { data: righe } = await admin.from("komunigo_ordini_righe")
        .select("*").eq("ordine_id", ord.id).order("ordine");
      const { data: files } = await admin.from("komunigo_ordini_file")
        .select("*").eq("ordine_id", ord.id).order("creato_il");
      // url di download firmati (1 ora) per far vedere/riscaricare i file caricati
      const fileOut: any[] = [];
      for (const f of (files || [])) {
        let url = null;
        try { const { data: sig } = await admin.storage.from(BUCKET).createSignedUrl(f.path, 3600); url = sig?.signedUrl || null; } catch (_) {}
        fileOut.push({ id: f.id, ordine_riga_id: f.ordine_riga_id, tipo: f.tipo || "cliente", nome_file: f.nome_file, dimensione: f.dimensione, mime: f.mime, stato: f.stato, url });
      }
      return json({
        ordine: {
          numero: ord.numero, stato: ord.stato, creato_il: ord.creato_il,
          cliente_nome: ord.cliente_nome, cliente_email: ord.cliente_email,
          spedizione: ord.spedizione, imponibile: ord.imponibile, iva: ord.iva, totale: ord.totale,
          pagamento_metodo: ord.pagamento_metodo, pagamento_stato: ord.pagamento_stato, pagamento_giorni: ord.pagamento_giorni,
          bozza_stato: ord.bozza_stato, bozza_feedback: ord.bozza_feedback,
        },
        righe: righe || [], file: fileOut,
      });
    }

    // -------------------------------------------------------------- FILE URL
    if (action === "file-url") {
      const ord = await ordineDaToken(admin, body.token);
      const rigaId = body.riga_id && uuidRe.test(body.riga_id) ? body.riga_id : "generale";
      const path = `${ord.id}/${rigaId}/${Date.now()}-${safeName(body.nome_file)}`;
      const { data, error } = await admin.storage.from(BUCKET).createSignedUploadUrl(path);
      if (error) throw new Error(error.message);
      return json({ ok: true, bucket: BUCKET, path: data.path, token: data.token });
    }

    // --------------------------------------------------------- FILE REGISTRA
    if (action === "file-registra") {
      const ord = await ordineDaToken(admin, body.token);
      const path = String(body.path || "");
      if (!path.startsWith(ord.id + "/")) throw new Error("Percorso file non valido");
      const rigaId = body.riga_id && uuidRe.test(body.riga_id) ? body.riga_id : null;
      const { data, error } = await admin.from("komunigo_ordini_file").insert({
        ordine_id: ord.id, ordine_riga_id: rigaId, path,
        nome_file: safeName(body.nome_file), dimensione: Number(body.dimensione) || null, mime: body.mime || null,
      }).select("id").single();
      if (error) throw new Error(error.message);
      return json({ ok: true, id: data.id });
    }

    // ---------------------------------------------------------- FILE ELIMINA
    if (action === "file-elimina") {
      const ord = await ordineDaToken(admin, body.token);
      const { data: f } = await admin.from("komunigo_ordini_file")
        .select("id,path,ordine_id").eq("id", body.file_id).maybeSingle();
      if (!f || f.ordine_id !== ord.id) throw new Error("File non trovato");
      try { await admin.storage.from(BUCKET).remove([f.path]); } catch (_) {}
      await admin.from("komunigo_ordini_file").delete().eq("id", f.id);
      return json({ ok: true });
    }

    // ---------------------------------------------------------- BOZZA APPROVA
    if (action === "bozza-approva") {
      const ord = await ordineDaToken(admin, body.token);
      if (ord.bozza_stato !== "da_approvare") throw new Error("Nessuna bozza da approvare");
      await admin.from("komunigo_ordini").update({ bozza_stato: "approvata", bozza_feedback: null }).eq("id", ord.id);
      return json({ ok: true });
    }

    // ---------------------------------------------------------- BOZZA MODIFICA
    if (action === "bozza-modifica") {
      const ord = await ordineDaToken(admin, body.token);
      if (ord.bozza_stato !== "da_approvare") throw new Error("Nessuna bozza in attesa");
      const note = String(body.note || "").slice(0, 2000);
      await admin.from("komunigo_ordini").update({ bozza_stato: "modifiche_richieste", bozza_feedback: note }).eq("id", ord.id);
      return json({ ok: true });
    }

    return json({ error: "Azione sconosciuta" }, 400);
  } catch (e) {
    return json({ error: String((e as Error).message || e) }, 400);
  }
});
