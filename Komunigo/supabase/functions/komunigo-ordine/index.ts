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
    return { prezzo_unitario: N > 0 ? r2(totG / N) : totG, prezzo_totale: totG, sotto_costo: totG < r2(costo), nome: prod.nome, quantita: N, unita_calcolo: "pz" };
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
  return { prezzo_unitario, prezzo_totale, sotto_costo: prezzo_totale < costo_totale, nome: prod.nome, quantita: N, unita_calcolo: u };
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

    // ---------------------------------------------------------------- CREA
    if (action === "crea") {
      const righeIn = Array.isArray(body.righe) ? body.righe : [];
      if (!righeIn.length) return json({ error: "Carrello vuoto" }, 400);

      // se il cliente è loggato, colleghiamo l'ordine al suo account
      let accountId: string | null = null;
      const authH = (req.headers.get("Authorization") || "").replace("Bearer ", "").trim();
      if (authH) { try { const { data: u } = await admin.auth.getUser(authH); accountId = u?.user?.id || null; } catch (_) { /* ospite */ } }

      const righe: any[] = [];
      let imponibileMerce = 0;
      for (const r of righeIn) {
        if (r.tipo === "configurabile") {
          const cfg = { ...(r.config || {}), quantita: (r.config?.quantita ?? r.quantita) };
          const p = await prezzoConfigurabile(admin, r.prodotto_config_id, cfg);
          if (!(p.prezzo_totale > 0) || p.sotto_costo) throw new Error(`Prezzo non valido per "${p.nome}"`);
          righe.push({
            tipo: "configurabile", prodotto_config_id: r.prodotto_config_id,
            descrizione: r.descrizione || p.nome, config: r.config || {},
            quantita: p.quantita, prezzo_unitario: p.prezzo_unitario, prezzo_totale: p.prezzo_totale,
          });
          imponibileMerce += p.prezzo_totale;
        } else {
          const { data: a } = await admin.from("articoli")
            .select("id,nome_articolo,prezzo_pubblico,vendibile,giacenza,impegnato").eq("id", r.articolo_id).maybeSingle();
          if (!a || a.vendibile !== true) throw new Error("Prodotto non disponibile");
          const disp = Math.max((Number(a.giacenza) || 0) - (Number(a.impegnato) || 0), 0);
          const qta = Math.max(1, Math.min(Number(r.quantita) || 1, disp || 1));
          const pu = Number(a.prezzo_pubblico) || 0;
          righe.push({
            tipo: "prodotto", articolo_id: a.id, descrizione: a.nome_articolo,
            config: {}, quantita: qta, prezzo_unitario: pu, prezzo_totale: Math.round(pu * qta * 100) / 100,
          });
          imponibileMerce += Math.round(pu * qta * 100) / 100;
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

      const cliente = body.cliente || {};
      const { data: ord, error: eOrd } = await admin.from("komunigo_ordini").insert({
        numero, stato: "nuovo",
        cliente_nome: cliente.nome || "", cliente_email: cliente.email || "", cliente_tel: cliente.tel || "",
        spedizione: { opzione: sped ? { id: sped.id, nome: sped.nome, prezzo: spedCosto, ritiro: !!sped.ritiro } : null, indirizzo: body.indirizzo || null },
        pagamento_metodo: body.pagamento_metodo || null, pagamento_stato: "in_attesa",
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
          pagamento_metodo: ord.pagamento_metodo, pagamento_stato: ord.pagamento_stato,
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
