// @ts-nocheck  (la trasformazione è JS puro, testabile anche con Node)
// =====================================================================
//  Edge Function: catalogo-fornitore
//  Scarica il catalogo del fornitore NEW WAVE (export JSON del portale NWG,
//  brand Clique) e lo scrive nelle tabelle di appoggio (migrazione komunigo-v16):
//    catalogo_fornitore_prodotti / _varianti / _sku  (upsert per codice)
//  Quello che non è più nel feed viene marcato attivo=false (mai cancellato).
//  Le scelte dello staff (selezionato, ricarico_pct, note) NON vengono toccate.
//  Aggiorna catalogo_fornitore_sync con esito e conteggi.
//
//  Secrets richiesti: NEWWAVE_FEED_URL (link export del portale NWG: contiene
//  la chiave, quindi va SOLO nei secrets, mai nel codice).
//  Env automatici Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
//
//  Deploy: Supabase -> Edge Functions -> Deploy new function, nome: catalogo-fornitore.
//  Chiamabile dal gestionale (sb.functions.invoke) e da un cron settimanale.
// =====================================================================
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const FORNITORE = "newwave";

// ---- TRASFORMAZIONE feed -> righe (pura, senza I/O) ----
// @@TRASFORMA-INIZIO
function trasformaNewWave(feed, adesso) {
  const it = (o) => (o && typeof o === "object") ? String(o.it ?? o.en ?? "") : String(o ?? "");
  const num = (x) => { const n = Number(x); return Number.isFinite(n) ? n : null; };
  const imgs = (lst) => (Array.isArray(lst) ? lst : []).map((i) => ({
    tipo: i.type || "", angolo: i.angle || "", anteprima: i.preview || "", alta: i.highRes || "",
  })).filter((i) => i.anteprima || i.alta);
  const prodotti = [], varianti = [], sku = [];
  for (const p of (Array.isArray(feed) ? feed : [])) {
    const codice = String(p.productNumber || "").trim();
    if (!codice) continue;
    prodotti.push({
      fornitore: FORNITORE, codice,
      nome: it(p.productName), brand: p.productBrandName || "",
      categoria: it(p.productCategory), descrizione: it(p.description),
      testo_catalogo: it(p.productCatalogText), linea: it(p.productCommerceText),
      genere: it(p.gender), vestibilita: it(p.productFit), tessuto: it(p.productFabrics),
      grammatura: String(p.productWeight || ""), taglie: String(p.productSize || ""),
      lavaggio: it(p.careInstructions), tecnica: it(p.productMaterialTechnique),
      note_tecnica: it(p.productTechniqueComment), codice_stampa: String(p.productPrintCode || ""),
      disponibile_dal: String(p.availableFrom || ""),
      immagini: imgs(p.images), attivo: true, aggiornato_il: adesso,
    });
    (p.variations || []).forEach((v, vi) => {
      const cc = String(v.colorCode ?? "").trim();
      varianti.push({
        fornitore: FORNITORE, codice: codice + "-" + cc, codice_prodotto: codice,
        codice_colore: cc, colore: it(v.color), immagini: imgs(v.images),
        ordine: vi, attivo: true, aggiornato_il: adesso,
      });
      (v.skus || []).forEach((s, si) => {
        const k = String(s.sku || "").trim();
        if (!k) return;
        sku.push({
          fornitore: FORNITORE, sku: k, codice_prodotto: codice, codice_colore: cc,
          taglia: String(s.name || ""), codice_taglia: String(s.size ?? ""), ordine: si,
          ean: String(s.ean || ""),
          prezzo_netto: num(s.customerPrice && s.customerPrice.value),
          prezzo_listino: num(s.retailPrice && s.retailPrice.value),
          pezzi_cartone: num(s.boxItems), lead_time: num(s.leadTime),
          attivo: s.active !== false, aggiornato_il: adesso,
        });
      });
    });
  }
  // dedup (lo stesso codice due volte nel feed farebbe fallire l'upsert)
  const uniq = (arr, key) => { const m = new Map(); arr.forEach((r) => m.set(r[key], r)); return [...m.values()]; };
  return { prodotti: uniq(prodotti, "codice"), varianti: uniq(varianti, "codice"), sku: uniq(sku, "sku") };
}
// @@TRASFORMA-FINE

async function rest(sbUrl: string, srv: string, path: string, method: string, body?: unknown, prefer = "") {
  const r = await fetch(`${sbUrl}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: srv, Authorization: "Bearer " + srv, "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`${method} ${path.split("?")[0]}: ${r.status} ${(await r.text()).slice(0, 300)}`);
}

async function upsert(sbUrl: string, srv: string, tabella: string, conflitto: string, righe: any[]) {
  const LOTTO = 1000;
  for (let i = 0; i < righe.length; i += LOTTO) {
    await rest(sbUrl, srv, `${tabella}?on_conflict=${conflitto}`, "POST", righe.slice(i, i + LOTTO),
      "resolution=merge-duplicates,return=minimal");
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const sbUrl = Deno.env.get("SUPABASE_URL")!;
  const srv = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const adesso = new Date().toISOString();
  const json = (o: unknown, status = 200) =>
    new Response(JSON.stringify(o), { status, headers: { ...cors, "Content-Type": "application/json" } });
  try {
    const url = Deno.env.get("NEWWAVE_FEED_URL");
    if (!url) throw new Error("NEWWAVE_FEED_URL non impostato nei secrets");

    const r = await fetch(url, { headers: { Accept: "application/json" } });
    if (!r.ok) throw new Error("Download feed New Wave: HTTP " + r.status);
    const feed = await r.json();
    if (!Array.isArray(feed) || feed.length === 0) throw new Error("Feed New Wave vuoto o non valido");
    const dataFeed = r.headers.get("last-modified") || "";

    const { prodotti, varianti, sku } = trasformaNewWave(feed, adesso);

    await upsert(sbUrl, srv, "catalogo_fornitore_prodotti", "fornitore,codice", prodotti);
    await upsert(sbUrl, srv, "catalogo_fornitore_varianti", "fornitore,codice", varianti);
    await upsert(sbUrl, srv, "catalogo_fornitore_sku", "fornitore,sku", sku);

    // ciò che NON era nel feed di oggi -> fuori catalogo (non cancello: ordini/scelte restano)
    const vecchi = `fornitore=eq.${FORNITORE}&aggiornato_il=lt.${encodeURIComponent(adesso)}`;
    for (const t of ["catalogo_fornitore_prodotti", "catalogo_fornitore_varianti", "catalogo_fornitore_sku"]) {
      await rest(sbUrl, srv, `${t}?${vecchi}&attivo=is.true`, "PATCH", { attivo: false }, "return=minimal");
    }

    const esito = "OK" + (dataFeed ? " · file fornitore del " + dataFeed : "");
    await rest(sbUrl, srv, `catalogo_fornitore_sync?fornitore=eq.${FORNITORE}`, "PATCH", {
      ultimo_sync: adesso, esito, n_prodotti: prodotti.length, n_varianti: varianti.length, n_sku: sku.length,
    }, "return=minimal");

    return json({ ok: true, prodotti: prodotti.length, varianti: varianti.length, sku: sku.length, file_del: dataFeed });
  } catch (e) {
    const msg = String((e as Error)?.message || e);
    try {
      await rest(sbUrl, srv, `catalogo_fornitore_sync?fornitore=eq.${FORNITORE}`, "PATCH",
        { ultimo_sync: adesso, esito: "ERRORE: " + msg.slice(0, 300) }, "return=minimal");
    } catch { /* ignora */ }
    return json({ ok: false, errore: msg });
  }
});
