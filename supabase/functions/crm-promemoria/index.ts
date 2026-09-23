// =====================================================================
//  Edge Function: crm-promemoria
//  Scansiona i promemoria CRM scaduti e non ancora notificati e invia
//  una email a chi ha creato l'attività (via Brevo API). Poi li marca
//  come inviati, così non partono due volte.
//
//  Va invocata a intervalli regolari (es. ogni 10 minuti) da un cron.
//
//  SECRET necessari (Supabase → Edge Functions → Secrets):
//    - BREVO_API_KEY   = chiave API v3 di Brevo (xkeysib-...)
//    - CRON_SECRET     = una password a caso, la stessa che metti nel cron
//    (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sono già forniti da Supabase)
//
//  Deploy: Dashboard → Edge Functions → Deploy new function, nome
//          "crm-promemoria". Disattiva "Verify JWT" (la protezione la fa
//          il CRON_SECRET qui sotto).
// =====================================================================

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const MITTENTE = { name: "Gestionale Creatio", email: "info@creatiogroup.it" };

function esc(s: string) {
  return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // --- protezione: serve il CRON_SECRET giusto ---
  const cronSecret = Deno.env.get("CRON_SECRET");
  const dato = req.headers.get("x-cron-secret");
  if (!cronSecret || dato !== cronSecret) {
    return new Response(JSON.stringify({ ok: false, errore: "non autorizzato" }),
      { status: 401, headers: { ...cors, "Content-Type": "application/json" } });
  }

  const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const BREVO = Deno.env.get("BREVO_API_KEY");

  try {
    if (!BREVO) throw new Error("BREVO_API_KEY non impostato nei secrets");

    // 1) leggi i promemoria da inviare (RPC security-definer)
    const rpc = await fetch(`${SUPA_URL}/rest/v1/rpc/promemoria_da_inviare`, {
      method: "POST",
      headers: {
        "apikey": SERVICE,
        "Authorization": "Bearer " + SERVICE,
        "Content-Type": "application/json",
      },
      body: "{}",
    });
    const righe = await rpc.json().catch(() => []);
    if (!rpc.ok) throw new Error("RPC promemoria_da_inviare: " + JSON.stringify(righe));

    if (!Array.isArray(righe) || righe.length === 0) {
      return new Response(JSON.stringify({ ok: true, inviati: 0, messaggio: "nessun promemoria da inviare" }),
        { headers: { ...cors, "Content-Type": "application/json" } });
    }

    const inviati: string[] = [];
    const errori: any[] = [];

    // 2) invia una email per ciascuno
    for (const r of righe) {
      const quando = new Date(r.promemoria_il).toLocaleString("it-IT",
        { dateStyle: "full", timeStyle: "short", timeZone: "Europe/Rome" });
      const html =
        `<div style="font-family:Arial,Helvetica,sans-serif;color:#1d2430">
          <h2 style="color:#00a7aa;margin:0 0 8px">⏰ Promemoria CRM</h2>
          <p style="margin:0 0 4px"><b>${esc(r.titolo || "Promemoria")}</b></p>
          <p style="margin:0 0 12px;color:#5b6773">${esc(quando)}</p>
          ${r.note ? `<p style="white-space:pre-line;background:#f4f6f8;padding:10px 12px;border-radius:8px;margin:0 0 12px">${esc(r.note)}</p>` : ""}
          <p style="margin:14px 0 0"><a href="https://gestionale.creatiogroup.it" style="background:#00a7aa;color:#fff;text-decoration:none;padding:9px 16px;border-radius:8px;font-weight:700">Apri il gestionale</a></p>
          <p style="margin:16px 0 0;font-size:12px;color:#8b95a1">Ciao ${esc(r.nome || "")}, questo è un promemoria automatico del CRM.</p>
        </div>`;

      const send = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": BREVO, "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify({
          sender: MITTENTE,
          to: [{ email: r.email, name: r.nome || r.email }],
          subject: "⏰ Promemoria: " + (r.titolo || "attività CRM"),
          htmlContent: html,
        }),
      });
      if (send.ok) inviati.push(r.id);
      else errori.push({ id: r.id, status: send.status, resp: await send.text().catch(() => "") });
    }

    // 3) marca come inviati quelli riusciti
    if (inviati.length) {
      await fetch(`${SUPA_URL}/rest/v1/rpc/segna_promemoria_inviato`, {
        method: "POST",
        headers: {
          "apikey": SERVICE,
          "Authorization": "Bearer " + SERVICE,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ p_ids: inviati }),
      });
    }

    return new Response(JSON.stringify({ ok: true, inviati: inviati.length, errori }),
      { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, errore: String(e) }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
