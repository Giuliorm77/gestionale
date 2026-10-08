// =====================================================================
//  Edge Function: fic-sync
//  Scarica da Fatture in Cloud (SOLA LETTURA) le fatture EMESSE (clienti) e
//  RICEVUTE (fornitori) con le loro RATE/scadenze (payments_list) e le scrive
//  nella tabella public.scadenze del gestionale (upsert per fic_payment_id).
//  Aggiorna public.scadenze_sync con esito e conteggi.
//
//  Secrets richiesti: FIC_TOKEN (access token Fatture in Cloud).
//  Env automatici Supabase: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
//  Company Creatio = 795064 (override con secret FIC_COMPANY).
//
//  Deploy: Supabase -> Edge Functions -> Deploy new function, nome: fic-sync.
//  Chiamabile dal gestionale (sb.functions.invoke) e da un cron notturno.
// =====================================================================
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const FIC = "https://api-v2.fattureincloud.it";

function toDate(s: any): string | null {
  if (!s) return null;
  const t = String(s).slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(t) ? t : null;
}

// Scarica tutte le pagine di una lista documenti (issued/received) di un dato type.
async function listaDocumenti(token: string, company: number, kind: string, type: string) {
  const out: any[] = [];
  let page = 1, last = 1;
  do {
    const url = `${FIC}/c/${company}/${kind}?type=${type}&fieldset=detailed&per_page=100&page=${page}`;
    const r = await fetch(url, { headers: { Authorization: "Bearer " + token, Accept: "application/json" } });
    const body = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(`${kind}/${type} HTTP ${r.status}: ${JSON.stringify(body).slice(0, 300)}`);
    (body.data || []).forEach((d: any) => out.push(d));
    last = Number(body.last_page || body.current_page || 1);
    page++;
  } while (page <= last);
  return out;
}

// Trasforma un documento FIC + le sue rate in righe "scadenze"
function righeDaDoc(doc: any, tipo: "cliente" | "fornitore") {
  const ent = doc.entity || {};
  const base = {
    tipo,
    fic_doc_id: doc.id ?? null,
    numero: [doc.numeration, doc.number].filter(Boolean).join("/") || String(doc.number ?? ""),
    data_documento: toDate(doc.date),
    controparte_nome: ent.name || "",
    controparte_piva: ent.vat_number || ent.tax_code || "",
    valuta: (doc.currency && doc.currency.id) || "EUR",
  };
  const pays = Array.isArray(doc.payments_list) ? doc.payments_list : [];
  if (!pays.length) {
    // documento senza rate: una scadenza unica dall'importo lordo
    return [{
      ...base,
      fic_payment_id: null,
      importo: Number(doc.amount_gross ?? doc.amount_net ?? 0) || 0,
      data_scadenza: toDate(doc.date),
      pagato: false,
      data_pagamento: null,
      metodo: "",
    }];
  }
  return pays.map((p: any) => ({
    ...base,
    fic_payment_id: p.id ?? null,
    importo: Number(p.amount ?? 0) || 0,
    data_scadenza: toDate(p.due_date),
    pagato: String(p.status || "").toLowerCase() === "paid",
    data_pagamento: toDate(p.paid_date),
    metodo: (p.payment_account && p.payment_account.name) || "",
  }));
}

async function upsertScadenze(sbUrl: string, srv: string, righe: any[]) {
  // upsert per fic_payment_id (le righe senza id vengono inserite come nuove)
  const conId = righe.filter((r) => r.fic_payment_id != null);
  const senzaId = righe.filter((r) => r.fic_payment_id == null);
  const headers = {
    apikey: srv, Authorization: "Bearer " + srv,
    "Content-Type": "application/json", Prefer: "resolution=merge-duplicates,return=minimal",
  };
  if (conId.length) {
    const r = await fetch(`${sbUrl}/rest/v1/scadenze?on_conflict=fic_payment_id`, { method: "POST", headers, body: JSON.stringify(conId) });
    if (!r.ok) throw new Error("upsert scadenze: " + r.status + " " + (await r.text()).slice(0, 300));
  }
  if (senzaId.length) {
    const r = await fetch(`${sbUrl}/rest/v1/scadenze`, { method: "POST", headers: { ...headers, Prefer: "return=minimal" }, body: JSON.stringify(senzaId) });
    if (!r.ok) throw new Error("insert scadenze (no id): " + r.status + " " + (await r.text()).slice(0, 300));
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const sbUrl = Deno.env.get("SUPABASE_URL")!;
  const srv = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  try {
    const token = Deno.env.get("FIC_TOKEN");
    if (!token) throw new Error("FIC_TOKEN non impostato nei secrets");
    const company = Number(Deno.env.get("FIC_COMPANY") || "795064");

    // CLIENTI: fatture emesse
    const emesse = await listaDocumenti(token, company, "issued_documents", "invoice");
    const righeCli = emesse.flatMap((d) => righeDaDoc(d, "cliente"));

    // FORNITORI: documenti ricevuti (spese + fatture passive)
    const ricevute: any[] = [];
    for (const t of ["expense", "passive_invoice"]) {
      try { (await listaDocumenti(token, company, "received_documents", t)).forEach((d) => ricevute.push(d)); } catch (_) { /* tipo non disponibile */ }
    }
    const righeFor = ricevute.flatMap((d) => righeDaDoc(d, "fornitore"));

    await upsertScadenze(sbUrl, srv, [...righeCli, ...righeFor]);

    // aggiorna stato sync
    await fetch(`${sbUrl}/rest/v1/scadenze_sync?id=eq.1`, {
      method: "PATCH",
      headers: { apikey: srv, Authorization: "Bearer " + srv, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ ultimo_sync: new Date().toISOString(), esito: "ok", n_clienti: righeCli.length, n_fornitori: righeFor.length }),
    });

    return new Response(JSON.stringify({ ok: true, clienti: righeCli.length, fornitori: righeFor.length }),
      { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    try {
      await fetch(`${sbUrl}/rest/v1/scadenze_sync?id=eq.1`, {
        method: "PATCH",
        headers: { apikey: srv, Authorization: "Bearer " + srv, "Content-Type": "application/json", Prefer: "return=minimal" },
        body: JSON.stringify({ ultimo_sync: new Date().toISOString(), esito: "errore: " + String(e).slice(0, 200) }),
      });
    } catch (_) { /* ignora */ }
    return new Response(JSON.stringify({ ok: false, errore: String(e) }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
