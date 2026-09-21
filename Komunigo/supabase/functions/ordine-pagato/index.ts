// =====================================================================
//  Edge Function: ordine-pagato
//  Cuore dell'automazione. Fa (lato server, con service_role):
//   1) RICALCOLA i prezzi del carrello (anti-manomissione: non ci si fida del browser);
//   2) crea l'ordine in komunigo_ordini / komunigo_ordini_righe;
//   3) apre la sessione di pagamento NEXI e restituisce la redirect_url;
//   4) [al webhook "pagato" di Nexi] -> IMPEGNA la merce in magazzino,
//      e se ci sono righe su misura crea una COMMESSA in produzione;
//      per i gadget prepara l'ordine neutri al fornitore + ALERT al commerciale.
//
//  NEXI: la parte sensibile delle carte la gestisce Nexi (XPay / hosted payment).
//  Servono le credenziali del terminale (alias, chiave MAC/secret) messe come
//  segreti della Edge Function, MAI nel browser:
//     supabase secrets set NEXI_ALIAS=... NEXI_SECRET=...
//
//  Deploy: supabase functions deploy ordine-pagato
//  STATO: stub. Da completare con: numerazione ordine, ricalcolo prezzi
//  (riusa prezzo-configuratore per le righe su misura), integrazione Nexi,
//  webhook di conferma + impegno/commessa/ordine-fornitore.
// =====================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { righe } = await req.json();
    if (!Array.isArray(righe) || righe.length === 0) throw new Error("Carrello vuoto");

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // TODO 1: ricalcolare qui i prezzi di ogni riga (mai fidarsi del browser).
    // TODO 2: numero = prossimo "K-AAAA-NNNN"; insert in komunigo_ordini(+_righe) stato='nuovo'.
    // TODO 3: creare la sessione Nexi (importo, ordine, url di ritorno) -> redirect_url.
    // TODO 4: webhook Nexi "pagato" -> update stato, impegno magazzino, commessa/ordine fornitore.

    return new Response(
      JSON.stringify({ _stub: true, messaggio: "Integrazione Nexi da completare", redirect_url: null }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }),
      { status: 400, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
