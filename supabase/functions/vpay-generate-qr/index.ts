import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Headers CORS: sin esto, el navegador bloquea la petición antes de que
// llegue aquí (la app móvil nunca los necesitó, pero la página web sí).
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // Preflight: el navegador manda esto ANTES del POST real para preguntar
  // si tiene permiso. Si no respondemos aquí, nunca llega el POST.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  try {
    const { id_transaccion } = await req.json();

    if (!id_transaccion) {
      return jsonResponse({ error: "id_transaccion es requerido" }, 400);
    }

    // 🔐 Cliente Supabase (SERVICE ROLE)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1️⃣ OBTENER DATOS DE LA TRANSACCIÓN
    const { data: tx, error: txError } = await supabase
      .from("transaccion")
      .select(`
        id_transaccion,
        monto,
        id_usuario,
        id_creador,
        id_plan,
        plan_suscripcion(nombre),
        creador(usuario(nombre_usuario))
      `)
      .eq("id_transaccion", id_transaccion)
      .eq("estado", "PEN")
      .single();

    if (txError || !tx) {
      return jsonResponse({ error: "Transacción no encontrada o inválida" }, 404);
    }

    const nombrePlan = tx.plan_suscripcion?.nombre ?? "Plan";
    const nombreCreador =
      tx.creador?.usuario?.nombre_usuario ?? "Creador";

    // 🔐 VARIABLES VPAY
    const vpUser = Deno.env.get("VPAY_USER")!;
    const vpPassword = Deno.env.get("VPAY_PASSWORD")!;
    const company = Deno.env.get("VPAY_COMPANY_ID")!;
    const callbackUrl = Deno.env.get("VPAY_CALLBACK_URL")!;

    // 2️⃣ LOGIN VPAY
    const loginRes = await fetch(
      "https://vpay.com.bo:7778/pro/api/auth/login",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user: vpUser,
          password: vpPassword,
          companyId: company,
        }),
      }
    );

    const loginData = await loginRes.json();
    const token = loginData?.transactionIdentifier;

    if (!token) {
      return jsonResponse({ error: "No se obtuvo token VPAY" }, 500);
    }

    // 3️⃣ GENERAR QR VPAY
    const expiration = new Date();
    expiration.setHours(expiration.getHours() + 1);

    const payload = {
      operation: "VTO041",
      header: [
        { attribute: "currency", value: "BOB" },
        { attribute: "gloss", value: `Suscripción ${nombrePlan} - ${nombreCreador}` },
        { attribute: "amount", value: tx.monto.toString() },
        {
          attribute: "expirationDate",
          value: expiration.toISOString().split("T")[0],
        },
        {
          attribute: "additionalData",
          value: `tx:${tx.id_transaccion}`,
        },
        { attribute: "destinationAccountId", value: "3332CO" },
        { attribute: "transactionIdentifier", value: token },
        { attribute: "user", value: vpUser },
        { attribute: "company", value: company },
        { attribute: "originCollection", value: "PWEB/APPM" },
        { attribute: "callback", value: callbackUrl },
      ],
      detail: [
        {
          items: [{ attribute: "SUBSCRIPTION", value: "1" }],
        },
      ],
    };

    const qrRes = await fetch(
      "https://vpay.com.bo:7778/pro/api/transactions/doPayment",
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: token,
        },
        body: JSON.stringify(payload),
      }
    );

    const qrData = await qrRes.json();

    const qrResponse = qrData?.responseList?.[0]?.response;
    const idQr = qrResponse?.find((r: any) => r.code === "idQr")?.identificator;
    const qrBase64 = qrResponse?.find((r: any) => r.code === "QR")?.identificator;

    if (!idQr || !qrBase64) {
      return jsonResponse({ error: "Error al generar QR VPAY", qrData }, 500);
    }

    // ✅ 4️⃣ ACTUALIZAR TRANSACCIÓN CON id_qr
    const { error: updError } = await supabase
      .from("transaccion")
      .update({
        id_qr: idQr,
        estado: "PEN",
      })
      .eq("id_transaccion", id_transaccion);

    if (updError) {
      return jsonResponse({ error: "Error al actualizar transacción" }, 500);
    }

    // 5️⃣ RESPUESTA A FLUTTER / WEB
    return jsonResponse({
      success: true,
      idQr,
      qr: qrBase64,
    });
  } catch (error) {
    return jsonResponse({ error: error.message }, 500);
  }
});
