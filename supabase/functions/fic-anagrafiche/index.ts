// =====================================================================
//  Edge Function: fic-anagrafiche
//  Importa CLIENTI e FORNITORI da Fatture in Cloud (SOLA LETTURA da FIC) e li
//  crea nelle anagrafiche del gestionale, DEDUPLICANDO per P.IVA/Codice Fiscale
//  (non ricrea chi è già presente). Campi fiscali core (ragione sociale, P.IVA,
//  CF, SDI, telefono). Indirizzi/email si arricchiscono a parte.
//
//  Body: { "tipo": "clienti" | "fornitori" | "both" }  (default: both)
//  Secrets: FIC_TOKEN (+ FIC_COMPANY opzionale). Env: SUPABASE_URL, SERVICE_ROLE.
//  Deploy: Supabase → Edge Functions → nome: fic-anagrafiche (Verify JWT OFF).
// =====================================================================
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const FIC = "https://api-v2.fattureincloud.it";

function normF(x: any): string | null {
  let u = String(x || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (/^[A-Z]{2}[0-9]{8,}$/.test(u)) u = u.slice(2);   // togli prefisso paese su P.IVA
  return u || null;
}

async function listaEntita(token: string, company: number, kind: string) {
  const out: any[] = [];
  const perPage = 100;
  let page = 1;
  while (page <= 200) {
    const url = `${FIC}/c/${company}/entities/${kind}?fieldset=detailed&per_page=${perPage}&page=${page}`;
    const r = await fetch(url, { headers: { Authorization: "Bearer " + token, Accept: "application/json" } });
    const body = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(`entities/${kind} HTTP ${r.status}: ${JSON.stringify(body).slice(0, 300)}`);
    const batch: any[] = body.data || [];
    batch.forEach((d) => out.push(d));
    const last = Number(body.last_page || 0);
    if (last) { if (page >= last) break; } else if (batch.length < perPage) break;
    if (batch.length === 0) break;
    page++;
  }
  return out;
}

async function sbGet(sbUrl: string, srv: string, path: string) {
  const r = await fetch(`${sbUrl}/rest/v1/${path}`, { headers: { apikey: srv, Authorization: "Bearer " + srv } });
  return r.ok ? await r.json() : [];
}
async function sbInsert(sbUrl: string, srv: string, table: string, rows: any[]) {
  if (!rows.length) return;
  for (let i = 0; i < rows.length; i += 200) {
    const chunk = rows.slice(i, i + 200);
    const r = await fetch(`${sbUrl}/rest/v1/${table}`, {
      method: "POST",
      headers: { apikey: srv, Authorization: "Bearer " + srv, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify(chunk),
    });
    if (!r.ok) throw new Error(`insert ${table}: ${r.status} ${(await r.text()).slice(0, 300)}`);
  }
}

// insieme delle chiavi fiscali (P.IVA/CF normalizzate) già presenti in anagrafica
function chiaviEsistenti(rows: any[]): Set<string> {
  const s = new Set<string>();
  rows.forEach((r) => { [normF(r.partita_iva), normF(r.codice_fiscale)].forEach((k) => { if (k) s.add(k); }); });
  return s;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const sbUrl = Deno.env.get("SUPABASE_URL")!;
  const srv = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  try {
    const token = Deno.env.get("FIC_TOKEN");
    if (!token) throw new Error("FIC_TOKEN non impostato nei secrets");
    const company = Number(Deno.env.get("FIC_COMPANY") || "795064");
    let tipo = "both";
    try { const b = await req.json(); if (b && b.tipo) tipo = b.tipo; } catch (_) { /* body vuoto */ }

    const res: any = {};

    if (tipo === "clienti" || tipo === "both") {
      const fic = await listaEntita(token, company, "clients");
      const esist = chiaviEsistenti(await sbGet(sbUrl, srv, "clienti?select=partita_iva,codice_fiscale"));
      const nuovi: any[] = [];
      let saltati = 0;
      for (const c of fic) {
        const keys = [normF(c.vat_number), normF(c.tax_code)].filter(Boolean) as string[];
        if (keys.some((k) => esist.has(k))) { saltati++; continue; }
        keys.forEach((k) => esist.add(k));   // evita doppioni nello stesso import
        nuovi.push({
          ragione_sociale: c.name || "(senza nome)",
          partita_iva: c.vat_number || "",
          codice_fiscale: c.tax_code || "",
          codice_sdi: c.ei_code || "",
          telefono: c.phone || "",
          categoria: "Cliente finale",
          stato: "Attivo",
        });
      }
      await sbInsert(sbUrl, srv, "clienti", nuovi);
      res.clienti = { da_fic: fic.length, creati: nuovi.length, gia_presenti: saltati };
    }

    if (tipo === "fornitori" || tipo === "both") {
      const fic = await listaEntita(token, company, "suppliers");
      const esist = chiaviEsistenti(await sbGet(sbUrl, srv, "fornitori?select=partita_iva,codice_fiscale"));
      const nuovi: any[] = [];
      let saltati = 0;
      for (const c of fic) {
        const keys = [normF(c.vat_number), normF(c.tax_code)].filter(Boolean) as string[];
        if (keys.some((k) => esist.has(k))) { saltati++; continue; }
        keys.forEach((k) => esist.add(k));
        nuovi.push({
          ragione_sociale: c.name || "(senza nome)",
          partita_iva: c.vat_number || "",
          codice_fiscale: c.tax_code || "",
        });
      }
      await sbInsert(sbUrl, srv, "fornitori", nuovi);
      res.fornitori = { da_fic: fic.length, creati: nuovi.length, gia_presenti: saltati };
    }

    return new Response(JSON.stringify({ ok: true, ...res }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, errore: String(e) }), { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
