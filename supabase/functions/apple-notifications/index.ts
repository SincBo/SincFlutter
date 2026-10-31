// Edge Function: apple-notifications
//
// Etapa 4 del plan de Apple In-App Purchase. Apple llama a esta URL cada vez
// que cambia el estado de una suscripción (renovación, cancelación, fallo de
// cobro, reembolso, vencimiento...), aunque el usuario no abra la app. Así la
// base de datos siempre refleja la realidad: se extiende fecha_fin cuando
// renueva y se corta el acceso cuando deja de pagar o pide reembolso.
//
// IMPORTANTE: esta función debe desplegarse con "Verify JWT" DESACTIVADO,
// porque Apple no manda un JWT de Supabase. (En el dashboard: Edge Functions
// -> apple-notifications -> Details/Settings -> desactivar "Verify JWT".)
//
// Seguridad: como la URL es pública, NO confiamos en el contenido de la
// notificación. Solo la usamos como aviso de "revisa esta suscripción": con
// el id de transacción que trae, le preguntamos a Apple directamente (App
// Store Server API, con nuestras credenciales) cuál es el estado real, y
// solo eso se escribe en la base de datos. Una notificación falsa no puede
// activar, extender ni cortar nada que Apple no confirme.
//
// Secrets (los mismos de verify-apple-purchase):
//   APPSTORE_IAP_KEY_ID, APPSTORE_IAP_PRIVATE_KEY, APPSTORE_ISSUER_ID,
//   APPLE_BUNDLE_ID (opcional, por defecto com.sincbo.sinc)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const APPLE_PROD = 'https://api.storekit.itunes.apple.com';
const APPLE_SANDBOX = 'https://api.storekit-sandbox.itunes.apple.com';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ---------------------------------------------------------------------
// Utilidades de JWT / JWS (iguales a verify-apple-purchase)
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

// Decodifica el payload de un JWS SIN verificar la firma (ver nota de
// seguridad arriba: solo se usa para saber qué consultar a Apple).
function decodeJws(jws: string): Record<string, any> {
  return JSON.parse(base64urlDecodeToString(jws.split('.')[1]));
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

async function buildServerApiJwt(bundleId: string): Promise<string> {
  const keyId = Deno.env.get('APPSTORE_IAP_KEY_ID')?.trim();
  const issuerId = Deno.env.get('APPSTORE_ISSUER_ID')?.trim();
  const privateKeyPem = Deno.env.get('APPSTORE_IAP_PRIVATE_KEY');
  if (!keyId || !issuerId || !privateKeyPem) {
    throw new Error(
      'Faltan secrets: revisa APPSTORE_IAP_KEY_ID, APPSTORE_ISSUER_ID y APPSTORE_IAP_PRIVATE_KEY',
    );
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 60 * 15,
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

// GET a la App Store Server API probando producción y luego sandbox.
// (Mientras la app no esté publicada, producción responde 401 para
// transacciones sandbox; ver verify-apple-purchase.)
async function appleGet(jwt: string, path: string) {
  for (const base of [APPLE_PROD, APPLE_SANDBOX]) {
    const res = await fetch(`${base}${path}`, {
      headers: { Authorization: `Bearer ${jwt}` },
    });
    const isProd = base === APPLE_PROD;
    if (res.status === 404 || (isProd && res.status === 401)) continue;
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      throw new Error(`Apple Server API ${res.status} (${base}): ${JSON.stringify(data)}`);
    }
    return data;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ ok: false, error: 'Method not allowed' }, 405);

  try {
    const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'com.sincbo.sinc';

    const { signedPayload } = await req.json();
    if (!signedPayload) return json({ ok: false, error: 'Falta signedPayload' }, 400);

    const notification = decodeJws(signedPayload);
    const type: string = notification.notificationType ?? '';
    const subtype: string = notification.subtype ?? '';

    // Notificación de prueba (botón "Request a test notification" de Apple)
    if (type === 'TEST') return json({ ok: true, test: true });

    const data = notification.data;
    if (!data?.signedTransactionInfo) return json({ ok: true, ignored: 'sin transacción' });
    if (data.bundleId && data.bundleId !== bundleId) {
      return json({ ok: true, ignored: 'otra app' });
    }

    // Solo para saber qué suscripción consultar (no se confía en más).
    const hintTx = decodeJws(data.signedTransactionInfo);
    const originalTxId = String(hintTx.originalTransactionId ?? '');
    if (!originalTxId) return json({ ok: true, ignored: 'sin originalTransactionId' });

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ¿Es una suscripción que ya conocemos?
    const { data: sub } = await admin
      .from('suscripcion')
      .select('id_suscripcion, id_usuario, id_creador, id_plan')
      .eq('apple_original_transaction_id', originalTxId)
      .maybeSingle();

    // Si todavía no está en la base (la notificación llegó antes de que la app
    // verificara la compra), no hay nada que actualizar: verify-apple-purchase
    // la creará con el estado real cuando la app la envíe.
    if (!sub) return json({ ok: true, ignored: 'suscripción desconocida' });

    const jwt = await buildServerApiJwt(bundleId);

    // Estado REAL de la suscripción según Apple
    const statusRes = await appleGet(
      jwt,
      `/inApps/v1/subscriptions/${encodeURIComponent(String(hintTx.transactionId))}`,
    );
    if (!statusRes) return json({ ok: true, ignored: 'Apple no reconoce la transacción' });

    let last: Record<string, any> | undefined;
    for (const group of statusRes.data ?? []) {
      for (const item of group.lastTransactions ?? []) {
        if (String(item.originalTransactionId) === originalTxId) last = item;
      }
    }
    if (!last) return json({ ok: true, ignored: 'sin estado para esta suscripción' });

    // status: 1 activa, 2 vencida, 3 reintentando cobro, 4 periodo de gracia, 5 revocada
    const status: number = last.status;
    const latestTx = decodeJws(last.signedTransactionInfo);
    const renewalInfo = last.signedRenewalInfo ? decodeJws(last.signedRenewalInfo) : null;

    const expiresMs = Number(latestTx.expiresDate ?? 0);
    const revoked = !!latestTx.revocationDate || status === 5;

    let endMs: number;
    if (revoked) {
      endMs = Math.min(Number(latestTx.revocationDate ?? Date.now()), Date.now());
    } else if (status === 4 && renewalInfo?.gracePeriodExpiresDate) {
      endMs = Number(renewalInfo.gracePeriodExpiresDate); // sigue con acceso en gracia
    } else {
      endMs = expiresMs; // activa: hasta el próximo cobro; vencida: ya pasó
    }

    const { error: updError } = await admin
      .from('suscripcion')
      .update({ fecha_fin: new Date(endMs).toISOString() })
      .eq('id_suscripcion', sub.id_suscripcion);
    if (updError) throw updError;

    // Renovación cobrada: registrar el pago del mes (una sola vez por transacción)
    if (!revoked && status === 1) {
      const { data: txExisting } = await admin
        .from('transaccion')
        .select('id_transaccion')
        .eq('apple_transaction_id', String(latestTx.transactionId))
        .maybeSingle();

      if (!txExisting) {
        const { data: plan } = await admin
          .from('plan_suscripcion')
          .select('precio')
          .eq('id_plan', sub.id_plan)
          .maybeSingle();

        const { error } = await admin.from('transaccion').insert({
          id_usuario: sub.id_usuario,
          id_creador: sub.id_creador,
          id_plan: sub.id_plan,
          monto: plan?.precio ?? null,
          estado: 'PAG',
          apple_transaction_id: String(latestTx.transactionId),
          payload_callback: latestTx,
        });
        if (error) throw error;
      }
    }

    // Reembolso: sacar ese pago de las ganancias del creador. Antes de tocar
    // nada, le preguntamos a Apple si de verdad esa transacción fue revocada.
    if (type === 'REFUND' || type === 'REVOKE') {
      const txRes = await appleGet(
        jwt,
        `/inApps/v1/transactions/${encodeURIComponent(String(hintTx.transactionId))}`,
      );
      const confirmed = txRes?.signedTransactionInfo
        ? decodeJws(txRes.signedTransactionInfo)
        : null;
      if (confirmed?.revocationDate) {
        const { error } = await admin
          .from('transaccion')
          .update({ estado: 'REF' }) // REF = reembolsada
          .eq('apple_transaction_id', String(confirmed.transactionId));
        if (error) throw error;
      }
    }

    return json({ ok: true, type, subtype, status, fecha_fin: new Date(endMs).toISOString() });
  } catch (e) {
    console.error('apple-notifications: error:', e);
    // 500 => Apple reintenta la notificación más tarde.
    return json({ ok: false, error: String(e) }, 500);
  }
});
