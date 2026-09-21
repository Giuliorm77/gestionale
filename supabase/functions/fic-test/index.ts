// =====================================================================
//  Edge Function: fic-test
//  Verifica il collegamento a Fatture in Cloud (SOLA LETTURA, sicura):
//  legge FIC_TOKEN dai secrets e chiede l'elenco aziende (company_id).
//  NON emette e non modifica nulla. Serve solo a confermare che token e
//  permessi funzionano prima di costruire la creazione fattura.
//
//  Deploy: Supabase Dashboard -> Edge Functions -> Functions ->
//          "Deploy a new function" (via editor), nome: fic-test.
//          Se c'è l'opzione "Verify JWT", disattivala per questa prova.
// =====================================================================
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const token = Deno.env.get("FIC_TOKEN");
    if (!token) throw new Error("FIC_TOKEN non impostato nei secrets");

    const r = await fetch("https://api-v2.fattureincloud.it/user/companies", {
      headers: { "Authorization": "Bearer " + token, "Accept": "application/json" },
    });
    const body = await r.json().catch(() => ({}));

    if (!r.ok) {
      return new Response(
        JSON.stringify({ ok: false, status: r.status, fic: body }),
        { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    const companies = (body && body.data && body.data.companies) || [];
    return new Response(
      JSON.stringify({
        ok: true,
        aziende: companies.map((c: any) => ({ id: c.id, nome: c.name, tipo: c.type })),
      }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ ok: false, errore: String(e) }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
