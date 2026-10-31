// Edge Function: inspect-iap-subscription  (SOLO DIAGNÓSTICO, solo lectura)
//
// Dado un id_plan, consulta a App Store Connect cómo quedó creada su
// suscripción (estado, precios, disponibilidad, plan types, localizaciones,
// captura de revisión) y lo devuelve tal cual, para entender por qué Apple
// dice "You must add a subscription price" al hacer "Add for Review".
// No modifica nada. Se puede borrar después de usarla.
//
// Body: { "id_plan": "<uuid>" }
// Usa los mismos secrets que create-iap-subscription
// (APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_PRIVATE_KEY).

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

function base64url(bytes: Uint8Array): string {
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
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

async function buildAppStoreJwt(): Promise<string> {
  const keyId = Deno.env.get('APPSTORE_KEY_ID')!;
  const issuerId = Deno.env.get('APPSTORE_ISSUER_ID')!;
  const privateKeyPem = Deno.env.get('APPSTORE_PRIVATE_KEY')!;
  const now = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const signingInput =
    `${base64url(encoder.encode(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' })))}.` +
    `${base64url(encoder.encode(JSON.stringify({ iss: issuerId, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' })))}`;
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

// Quita los "links" (ruido) para que el resultado sea corto y entre completo
function slim(x: any): any {
  if (Array.isArray(x)) return x.map(slim);
  if (x && typeof x === 'object') {
    const out: Record<string, any> = {};
    for (const [k, v] of Object.entries(x)) {
      if (k === 'links' || k === 'meta') continue;
      out[k] = slim(v);
    }
    return out;
  }
  return x;
}

async function get(jwt: string, path: string) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    headers: { Authorization: `Bearer ${jwt}` },
  });
  const body = await res.json().catch(() => null);
  return { path, status: res.status, body: slim(body) };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    // Dos formas de usarla:
    //  - { "id_plan": "<uuid>" }          -> suscripción creada por create-iap-subscription
    //  - { "subscription_id": "6820..." } -> cualquier suscripción por su Apple ID
    //    (por ejemplo, una creada a mano en App Store Connect, para comparar)
    const { id_plan, subscription_id } = await req.json();
    const jwt = await buildAppStoreJwt();

    let plan: any = null;
    let id: string;

    if (subscription_id) {
      id = String(subscription_id);
    } else {
      const admin = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      );
      const { data, error } = await admin
        .from('plan_suscripcion')
        .select('id_plan, nombre, apple_product_id, apple_subscription_group_id')
        .eq('id_plan', id_plan)
        .single();
      if (error || !data) return json({ error: `Plan no encontrado: ${error?.message}` }, 404);
      plan = data;

      // Encontrar la suscripción dentro de su grupo
      const subs = await get(
        jwt,
        `/v1/subscriptionGroups/${plan.apple_subscription_group_id}/subscriptions?limit=50`,
      );
      const sub = (subs.body?.data ?? []).find(
        (s: any) => s.attributes?.productId === plan.apple_product_id,
      );
      if (!sub) return json({ plan, subs });
      id = sub.id;
    }

    const results = await Promise.all([
      get(jwt, `/v1/subscriptions/${id}?fields%5Bsubscriptions%5D=name,productId,state,subscriptionPeriod,multiSeatStatus,marketSettings,familySharable`),
      // Se omite el detalle de la suscripción (ya lo sabemos); lo importante:
      get(jwt, `/v1/subscriptions/${id}/versions`),
      get(jwt, `/v1/subscriptions/${id}/prices?include=subscriptionPricePoint,territory&limit=200`),
      get(jwt, `/v1/subscriptions/${id}/planAvailabilities?limit=50`),
      get(jwt, `/v1/subscriptions/${id}/subscriptionAvailability?include=availableTerritories`),
      get(jwt, `/v1/subscriptions/${id}/subscriptionLocalizations`),
      get(jwt, `/v1/subscriptions/${id}/appStoreReviewScreenshot`),
    ]);

    return json({ plan, subscriptionId: id, results });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
