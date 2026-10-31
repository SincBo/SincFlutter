// Edge Function: verify-apple-purchase
//
// Etapa 3 del plan de Apple In-App Purchase. La app (iOS) la llama después
// de que el usuario pagó con Apple. Esta función NO confía en lo que diga la
// app: le pregunta directamente a Apple (App Store Server API) por la
// transacción, valida que sea de nuestra app y del producto de un plan real,
// y recién entonces activa la suscripción en la base de datos.
//
// Body: { "transaction_id": "...", "product_id": "...", "restored": false }
// Requiere el JWT del usuario (Authorization: Bearer <access_token>), que la
// app ya manda automáticamente con supabase.functions.invoke().
//
// Secrets necesarios (Edge Functions -> Secrets):
//   APPSTORE_IAP_KEY_ID        -> Key ID de la llave "In-App Purchase"
//   APPSTORE_IAP_PRIVATE_KEY   -> contenido del .p8 de esa llave
//   APPSTORE_ISSUER_ID         -> el mismo Issuer ID que ya tienes
//   APPLE_BUNDLE_ID            -> (opcional) por defecto com.sincbo.sinc
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY los inyecta
// Supabase solos.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

const APPLE_PROD = 'https://api.storekit.itunes.apple.com';
const APPLE_SANDBOX = 'https://api.storekit-sandbox.itunes.apple.com';

// ---------------------------------------------------------------------
// JWT ES256 para autenticar contra la App Store Server API.
// ---------------------------------------------------------------------
function base64url(bytes: Uint8Array): string {
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlDecodeToString(input: string): string {
  const b64 = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  const raw = atob(padded);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return new TextDecoder().decode(bytes);
}

function pemToDer(pem: string): Uint8Array {
  const clean = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const raw = atob(clean);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

// Solo para diagnóstico en el mensaje de error (no son datos secretos).
let kidInUse = '';
let issuerInUse = '';

async function buildServerApiJwt(bundleId: string): Promise<string> {
  const keyId = Deno.env.get('APPSTORE_IAP_KEY_ID')?.trim();
  const issuerId = Deno.env.get('APPSTORE_ISSUER_ID')?.trim();
  const privateKeyPem = Deno.env.get('APPSTORE_IAP_PRIVATE_KEY');
  if (!keyId || !issuerId || !privateKeyPem) {
    throw new Error(
      'Faltan secrets: revisa APPSTORE_IAP_KEY_ID, APPSTORE_ISSUER_ID y APPSTORE_IAP_PRIVATE_KEY',
    );
  }
  kidInUse = keyId;
  issuerInUse = issuerId;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 60 * 30,
    aud: 'appstoreconnect-v1',
    bid: bundleId,
  };

  const encoder = new TextEncoder();
  const signingInput =
    `${base64url(encoder.encode(JSON.stringify(header)))}.` +
    `${base64url(encoder.encode(JSON.stringify(payload)))}`;

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(privateKeyPem),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    encoder.encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

// Consulta la transacción a Apple. Primero producción; si Apple dice que no
// la conoce (404), probamos sandbox (compras de prueba / TestFlight / revisión).
// La respuesta viene directo de Apple por HTTPS con nuestras credenciales, por
// eso se puede confiar en ella sin volver a verificar la cadena de
// certificados del JWS.
async function fetchAppleTransaction(jwt: string, transactionId: string) {
  for (const base of [APPLE_PROD, APPLE_SANDBOX]) {
    const res = await fetch(
      `${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
      { headers: { Authorization: `Bearer ${jwt}` } },
    );
    // Producción responde 404 si la transacción no es suya (es sandbox). Además,
    // mientras la app aún no está publicada en la App Store, Apple responde 401
    // en producción para transacciones sandbox. En ambos casos probamos sandbox.
    // Un 401 en sandbox sí es un problema real de credenciales y se reporta.
    const isProd = base === APPLE_PROD;
    if (res.status === 404 || (isProd && res.status === 401)) continue;
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      throw new Error(
        `Apple Server API ${res.status} (${base}) kid=${kidInUse} issuer=${issuerInUse}: ${JSON.stringify(data)}`,
      );
    }
    const signed: string | undefined = data?.signedTransactionInfo;
    if (!signed) throw new Error('Apple no devolvió signedTransactionInfo');
    const payload = JSON.parse(base64urlDecodeToString(signed.split('.')[1]));
    return payload as Record<string, any>;
  }
  return null; // ni producción ni sandbox la conocen
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ ok: false, error: 'Method not allowed' }, 405);

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.sincbo.sinc';

    // 1. Quién es el usuario que llama (por su JWT, no por lo que diga el body)
    const authHeader = req.headers.get('Authorization') ?? '';
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    const user = userData?.user;
    if (userError || !user) return json({ ok: false, error: 'No autenticado' }, 401);

    const { transaction_id } = await req.json();
    if (!transaction_id) return json({ ok: false, error: 'transaction_id es requerido' }, 400);

    // 2. Preguntarle a Apple por la transacción
    const jwt = await buildServerApiJwt(bundleId);
    const tx = await fetchAppleTransaction(jwt, String(transaction_id));
    if (!tx) return json({ ok: false, error: 'Apple no reconoce esta transacción' }, 404);

    // 3. Validaciones básicas de la transacción
    if (tx.bundleId !== bundleId) {
      return json({ ok: false, error: 'La transacción es de otra app' }, 403);
    }
    if (tx.revocationDate) {
      // Reembolsada o revocada por Apple: no se activa.
      return json({ ok: true, active: false, reason: 'revoked' });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);

    // 4. Producto de Apple -> plan real de Sinc (no confiamos en el cliente)
    const { data: plan, error: planError } = await admin
      .from('plan_suscripcion')
      .select('id_plan, id_creador, precio')
      .eq('apple_product_id', tx.productId)
      .maybeSingle();
    if (planError || !plan) {
      return json({ ok: false, error: `Producto desconocido: ${tx.productId}` }, 404);
    }

    const expiresMs = Number(tx.expiresDate ?? 0);
    const active = expiresMs > Date.now();
    if (!active) {
      // Compra vieja ya vencida (p. ej. al restaurar): se da por procesada
      // pero no se activa nada.
      return json({ ok: true, active: false, reason: 'expired' });
    }
    const expiresIso = new Date(expiresMs).toISOString();
    const originalTxId = String(tx.originalTransactionId);

    // 5. Una compra de Apple solo puede pertenecer a UNA cuenta de Sinc
    const { data: owner } = await admin
      .from('suscripcion')
      .select('id_usuario')
      .eq('apple_original_transaction_id', originalTxId)
      .maybeSingle();
    if (owner && owner.id_usuario !== user.id) {
      return json(
        { ok: false, error: 'Esta compra de Apple ya está asociada a otra cuenta de Sinc.' },
        409,
      );
    }

    // 6. Crear o extender la suscripción
    const { data: existing } = await admin
      .from('suscripcion')
      .select('id_suscripcion')
      .eq('id_usuario', user.id)
      .eq('id_plan', plan.id_plan)
      .maybeSingle();

    if (existing) {
      const { error } = await admin
        .from('suscripcion')
        .update({
          fecha_fin: expiresIso,
          apple_original_transaction_id: originalTxId,
          apple_product_id: tx.productId,
        })
        .eq('id_suscripcion', existing.id_suscripcion);
      if (error) throw error;
    } else {
      const { error } = await admin.from('suscripcion').insert({
        id_usuario: user.id,
        id_creador: plan.id_creador,
        id_plan: plan.id_plan,
        fecha_inicio: new Date().toISOString(),
        fecha_fin: expiresIso,
        apple_original_transaction_id: originalTxId,
        apple_product_id: tx.productId,
      });
      if (error) throw error;
    }

    // 7. Registrar el pago (una sola vez por transacción de Apple). El monto
    //    es el precio del plan en Bs, igual que en los pagos por VPay, para
    //    que las ganancias del creador se calculen igual. Las comisiones de
    //    Apple y el monto real en USD quedan en payload_callback.
    const { data: txExisting } = await admin
      .from('transaccion')
      .select('id_transaccion')
      .eq('apple_transaction_id', String(tx.transactionId))
      .maybeSingle();

    if (!txExisting) {
      const { error } = await admin.from('transaccion').insert({
        id_usuario: user.id,
        id_creador: plan.id_creador,
        id_plan: plan.id_plan,
        monto: plan.precio,
        estado: 'PAG',
        apple_transaction_id: String(tx.transactionId),
        payload_callback: tx,
      });
      if (error) throw error;
    }

    return json({ ok: true, active: true, expires: expiresIso });
  } catch (e) {
    console.error('verify-apple-purchase: error:', e);
    return json({ ok: false, error: String(e) }, 500);
  }
});
