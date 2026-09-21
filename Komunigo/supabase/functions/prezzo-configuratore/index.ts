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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { prodotto_id, variante_id, larghezza_cm, altezza_cm, quantita, opzioni, stampe } = await req.json();
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
      return new Response(JSON.stringify({
        prezzo_unitario: N > 0 ? r2(totG / N) : totG,
        prezzo_totale: totG, dettaglio, sotto_costo: totG < r2(costo), minimo: Number(prod.minimo) || 0, valuta: "EUR",
      }), { headers: { ...cors, "Content-Type": "application/json" } });
    }

    const sel = new Set(Array.isArray(opzioni) ? opzioni : []);

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
    const sotto_costo = prezzo_totale < costo_totale;

    return new Response(JSON.stringify({ prezzo_unitario, prezzo_totale, sotto_costo, valuta: "EUR" }),
      { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }),
      { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
