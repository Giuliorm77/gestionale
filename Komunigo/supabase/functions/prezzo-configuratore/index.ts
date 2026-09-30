// =====================================================================
//  Edge Function: prezzo-configuratore
//  Calcola il PREZZO di un prodotto configurabile lato SERVER, replicando
//  ESATTAMENTE calcolaConfigurato() del gestionale. Legge i costi con la
//  service_role (mai esposti); restituisce solo prezzo_unitario/totale (netti).
//
//  Deploy (dashboard): Edge Functions -> Functions -> Deploy a new function ->
//    nome ESATTO: prezzo-configuratore ; Verify JWT: OFF (prezzi sono pubblici).
//
//  Input (body): { prodotto_id, variante_id, larghezza_cm, altezza_cm, quantita, opzioni:[voce_id...] }
// =====================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ---- SCONTO B2B (cliente loggato) --------------------------------------
// Replica la logica del gestionale (scontoPerCategoria): eccezione per
// categoria dell'articolo -> sconto standard del cliente -> sconto
// rivenditori standard. Attivo solo se l'account e' su stato 'b2b' e
// collegato a un cliente in anagrafica. Non espone mai costi.
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
  let fmtNome: string, perStock: number, pose: number;
  if (grande) { fmtNome = "Grande formato"; perStock = 1; pose = poseIn(sw - 2 * marg, sh - 2 * marg, fw, fh); }
  else {
    const cand = FORMATI_STAMPA.map((F) => {
      const ps = poseIn(F.l - 2 * marg, F.h - 2 * marg, fw, fh);
      const pst = poseIn(sw, sh, F.l, F.h);
      return { F, pose: ps, perStock: pst, pezziStock: ps * Math.max(1, pst) };
    });
    let selc = (opts.fmt && opts.fmt !== "auto") ? cand.find((c) => c.F.nome === opts.fmt) : null;
    if (!selc) selc = cand.slice().sort((a, b) => b.pezziStock - a.pezziStock)[0];
    fmtNome = selc.F.nome; pose = selc.pose; perStock = Math.max(1, selc.perStock);
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
  return { costo: costoCarta + costoStampa, pose, perStock, fogliMacchina, fogliAcq, fmtNome, grande, valido: pose > 0 };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { prodotto_id, variante_id, larghezza_cm, altezza_cm, quantita, opzioni, stampe,
      st_macchina, st_fr, st_colore, st_fmt } = await req.json();
    if (!prodotto_id) throw new Error("prodotto_id mancante");
    const N = Number(quantita) || 0;

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    const { data: prod, error } = await admin
      .from("prodotti_config")
      .select("*, prodotti_config_varianti(*), prodotti_config_voci(*), prodotti_config_fasce(*), prodotti_config_stampe(*)")
      .eq("id", prodotto_id).single();
    if (error || !prod) throw new Error("Prodotto non trovato");

    const { data: imp } = await admin.from("impostazioni").select("abbondanza_cm").limit(1).maybeSingle();
    const abb = Number(imp?.abbondanza_cm) || 0;

    // sconto riservato del cliente loggato (0 se ospite o non B2B)
    const profB2b = await caricaProfiloB2b(admin, req.headers.get("Authorization"));
    const scB2b = scForCat(profB2b, (prod as any).categoria);

    const varr = prod.prodotti_config_varianti || [];
    const va = varr.find((v: any) => v.id === variante_id) || varr[0] || { costo_materiale: 0, sfrido_pct: 0, spessore: 0 };

    // costo materiale: se la variante è legata a un articolo, usa il costo dell'articolo
    let costoMat = Number(va.costo_materiale) || 0;
    if (va.articolo_id) {
      const { data: a } = await admin.from("articoli").select("costo").eq("id", va.articolo_id).maybeSingle();
      if (a && a.costo != null) costoMat = Number(a.costo) || 0;
    }

    // ---- GADGET: variante colore + posizioni di stampa (niente misure) ----
    if (prod.tipo === "gadget") {
      const r2 = (x: number) => Math.round(x * 100) / 100;
      const costoBase = costoMat * N * (1 + (Number(va.sfrido_pct) || 0) / 100);
      const allSt = prod.prodotti_config_stampe || [];
      const scelte = Array.isArray(stampe) ? stampe : [];
      const stCost: any[] = [];
      let costoSetup = 0;
      for (const sc of scelte) {
        const st = allSt.find((x: any) => x.id === sc.stampa_id);
        if (!st) continue;
        const colori = Math.max(1, Math.min(Number(sc.colori) || 1, Number(st.max_colori) || 4));
        stCost.push({ nome: st.nome, colori, costo: (Number(st.prezzo_pz) || 0) * colori * N });
        costoSetup += Number(st.setup) || 0;
      }
      const costo = costoBase + stCost.reduce((s, x) => s + x.costo, 0) + costoSetup;
      const mg = Number(prod.margine_pct) || 0;
      const mFactor = mg > 0 ? 1 / (1 - mg / 100) : 1;
      const fasceG = (prod.prodotti_config_fasce || []).slice()
        .sort((a: any, b: any) => (Number(b.da_quantita) || 0) - (Number(a.da_quantita) || 0));
      const faG = fasceG.find((x: any) => N >= (Number(x.da_quantita) || 0));
      const factor = mFactor * (faG ? (1 - (Number(faG.sconto_pct) || 0) / 100) : 1);
      const dettaglio = {
        prodotto: r2(costoBase * factor),
        stampe: stCost.map((x) => ({ nome: x.nome, colori: x.colori, prezzo: r2(x.costo * factor) })),
        impianto: r2(costoSetup * factor),
      };
      const totG = r2(dettaglio.prodotto + dettaglio.stampe.reduce((s: number, x: any) => s + x.prezzo, 0) + dettaglio.impianto);
      const netG = scB2b > 0 ? r2(totG * (1 - scB2b / 100)) : totG;
      return new Response(JSON.stringify({
        prezzo_unitario: N > 0 ? r2(netG / N) : netG,
        prezzo_totale: netG,
        prezzo_listino_totale: totG, prezzo_listino_unitario: N > 0 ? r2(totG / N) : totG, sconto_pct: scB2b,
        dettaglio, sotto_costo: netG < r2(costo), minimo: Number(prod.minimo) || 0, valuta: "EUR",
      }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    const sel = new Set(Array.isArray(opzioni) ? opzioni : []);

    // ---- STAMPA SU CARTA (nesting a fogli) ----
    if (prod.tipo === "stampa") {
      const r2 = (x: number) => Math.round(x * 100) / 100;
      const Ls = Number(larghezza_cm) || 0, Hs = Number(altezza_cm) || 0;
      const opts = { macchina: st_macchina || "piccolo", fr: !!st_fr, colore: !!st_colore, fmt: st_fmt || "auto" };
      const s = calcStampa(prod, va, Ls, Hs, N, opts, costoMat);
      let costoS = s.costo;
      (prod.prodotti_config_voci || []).forEach((voce: any) => {
        if (voce.opzionale && !sel.has(voce.id)) return;
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
      const net = scB2b > 0 ? r2(tot * (1 - scB2b / 100)) : tot;
      return new Response(JSON.stringify({
        prezzo_unitario: N > 0 ? r2(net / N) : net, prezzo_totale: net,
        prezzo_listino_totale: tot, prezzo_listino_unitario: N > 0 ? r2(tot / N) : tot, sconto_pct: scB2b,
        sotto_costo: net < r2(costoS), valuta: "EUR",
        impaginazione: { pose: s.pose, fogliMacchina: s.fogliMacchina, fogliAcquisto: s.fogliAcq, formato: s.fmtNome, grande: s.grande, valido: s.valido },
      }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    // ---- replica ESATTA di calcolaConfigurato() (prodotti a MISURA) ----
    const u = prod.unita_calcolo;
    const L = Number(larghezza_cm) || 0, H = Number(altezza_cm) || 0, sp = Number(va.spessore) || 0;
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
      // voci a quantità manuale (modo diverso da u e non "fisso") non sono richieste online -> 0
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
    const prezzo_unitario = N > 0 ? Math.round((prezzo / N) * 100) / 100 : prezzo_totale;

    // Rete di sicurezza: segnala (senza esporre il costo) se il prezzo non copre
    // il costo TOTALE (materiale + voci). Il costo NON lascia mai il server.
    const costo_totale = Math.round(costo * 100) / 100;

    // sconto B2B applicato sul prezzo finale (dopo margine/fasce/minimo)
    const net_totale = scB2b > 0 ? Math.round(prezzo_totale * (1 - scB2b / 100) * 100) / 100 : prezzo_totale;
    const net_unitario = N > 0 ? Math.round((net_totale / N) * 100) / 100 : net_totale;
    const sotto_costo = net_totale < costo_totale;

    return new Response(JSON.stringify({
      prezzo_unitario: net_unitario, prezzo_totale: net_totale,
      prezzo_listino_totale: prezzo_totale, prezzo_listino_unitario: prezzo_unitario, sconto_pct: scB2b,
      sotto_costo, valuta: "EUR",
    }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }),
      { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
