// =====================================================================
//  Edge Function: fic-doc-test  (TEMPORANEA — da cancellare a fine test)
//  Prova di SCRITTURA su Fatture in Cloud: crea un documento (di default un
//  PROFORMA di prova, non fiscale e cancellabile). Accetta nel body un
//  { "data": {...} } così si può variare il payload senza ripubblicare.
//  NON invia allo SDI. Company Creatio = 795064.
// =====================================================================
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const COMPANY = 795064;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const token = Deno.env.get("FIC_TOKEN");
    if (!token) throw new Error("FIC_TOKEN mancante nei secrets");

    const oggi = new Date().toISOString().slice(0, 10);
    let payload: any = null;
    try { const b = await req.json(); if (b && b.data) payload = b; } catch (_) { /* body vuoto */ }
    if (!payload) {
      payload = { data: {
        type: "proforma",
        entity: { name: "CLIENTE DI PROVA (test integrazione)" },
        date: oggi,
        items_list: [{ name: "Articolo di prova", qty: 1, net_price: 100, vat: { id: 0 } }],
      }};
    }

    const r = await fetch(`https://api-v2.fattureincloud.it/c/${COMPANY}/issued_documents`, {
      method: "POST",
      headers: { "Authorization": "Bearer " + token, "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify(payload),
    });
    const body = await r.json().catch(() => ({}));
    return new Response(JSON.stringify({ status: r.status, ok: r.ok, fic: body }, null, 2),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, errore: String(e) }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
