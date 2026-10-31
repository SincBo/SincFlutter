// Edge Function: create-iap-subscription
//
// Etapa 1 del plan de Apple In-App Purchase. Dado un id_plan (fila de
// plan_suscripcion), crea en App Store Connect:
//   1. Un Subscription Group nuevo (uno por creador+plan, para que un fan
//      pueda estar suscrito a varios creadores/planes a la vez sin que se
//      cancelen entre sí -- Apple solo permite UNA suscripción activa por
//      grupo).
//   2. Una versión + localización del grupo (nombre visible al usuario).
//   3. La suscripción (producto) dentro de ese grupo.
//   4. Su localización (nombre/descripción visibles).
//   5. Su precio, mapeado al price point de Apple más cercano al precio
//      que el creador pidió (Apple no permite precio 100% libre; con ~800
//      price points por moneda, el redondeo es mínimo).
//
// Guarda el resultado en plan_suscripcion.apple_product_id /
// apple_subscription_group_id / apple_status.
//
// Esta función NO la llama la app -- la llama Pablo/su equipo (por ejemplo
// con curl o Postman) cuando dan de alta el plan de un creador, ya que hoy
// los precios los define el equipo manualmente (el creador les escribe
// pidiendo sus planes). Body esperado: { "id_plan": "<uuid>" }.
//
// Requiere estos secrets en Supabase (Edge Functions -> Secrets):
//   APPSTORE_KEY_ID           -> el Key ID de la API key (ej. 736J25UNLU)
//   APPSTORE_ISSUER_ID        -> el Issuer ID
//   APPSTORE_PRIVATE_KEY      -> el contenido completo del archivo .p8
//                                (con los saltos de línea, tal cual)
//   APPSTORE_APP_ID           -> el Apple ID numérico de la app (ej. 6768064278)
// Además de los ya conocidos SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY que
// Supabase inyecta solo.

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

// Territorio de Apple para Bolivia (ISO alpha-3, como usa la App Store
// Connect API: "USA", "MEX", "BOL", etc.)
// Bolivia es el mercado real; USA se agrega porque los revisores de Apple
// prueban con cuentas sandbox de la tienda de EE.UU. y, si el producto no
// existe ahí, la compra no aparece y la app puede ser rechazada.
const TERRITORIES = ['BOL', 'USA'];
// Locale usado para la localización de nombre/descripción. Apple no tiene
// un locale de español boliviano dedicado; usamos español latinoamericano.
const LOCALE = 'es-MX';

// Tipo de plan de cobro. UPFRONT = se paga el precio completo del periodo
// (1 mes) al inicio de cada renovación: la suscripción mensual normal, que
// el usuario puede cancelar cuando quiera. MONTHLY, en cambio, es la
// modalidad "pago mensual con compromiso de 12 meses": NO es lo que queremos.
const PLAN_TYPE = 'UPFRONT';

// Solo para devolver en la respuesta (informativo)
const APPSTORE_API_BASE ='https://api.appstoreconnect.apple.com';

// ---------------------------------------------------------------------
// JWT firmado con ES256 para autenticar contra la App Store Connect API.
// ---------------------------------------------------------------------
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
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 60 * 15, // 15 min (máximo permitido: 20 min)
    aud: 'appstoreconnect-v1',
  };

  const encoder = new TextEncoder();
  const headerB64 = base64url(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64url(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const keyData = pemToDer(privateKeyPem);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
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

async function appStoreFetch(
  jwt: string,
  path: string,
  options: { method?: string; body?: unknown } = {},
) {
  const res = await fetch(`${APPSTORE_API_BASE}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      Authorization: `Bearer ${jwt}`,
      'Content-Type': 'application/json',
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const data = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(
      `Apple API ${options.method ?? 'GET'} ${path} -> ${res.status}: ${JSON.stringify(data)}`,
    );
  }
  return data;
}

// Encuentra, entre los price points disponibles para el territorio, el
// más cercano al precio deseado (en la moneda local de ese territorio).
function closestPricePoint(pricePoints: any[], targetPrice: number) {
  let best = pricePoints[0];
  let bestDiff = Infinity;
  for (const p of pricePoints) {
    const price = parseFloat(p.attributes.customerPrice);
    const diff = Math.abs(price - targetPrice);
    if (diff < bestDiff) {
      bestDiff = diff;
      best = p;
    }
  }
  return best;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { id_plan } = await req.json();
    if (!id_plan) return json({ error: 'id_plan es requerido' }, 400);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const appId = Deno.env.get('APPSTORE_APP_ID')!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // 1. Leer el plan + nombre del creador
    const { data: plan, error: planError } = await admin
      .from('plan_suscripcion')
      .select('id_plan, nombre, precio, id_creador, creador(usuario(nombre_usuario))')
      .eq('id_plan', id_plan)
      .single();

    if (planError || !plan) {
      return json({ error: `Plan no encontrado: ${planError?.message}` }, 404);
    }

    const nombreCreador =
      (plan as any).creador?.usuario?.nombre_usuario ?? 'Creador';
    const referenceName = `${nombreCreador} - ${plan.nombre}`.slice(0, 100);
    // Product ID único, sin espacios, solo alfanumérico/puntos/guiones bajos.
    const productId = `com.sincbo.sinc.plan.${id_plan}`.replace(/-/g, '');

    const jwt = await buildAppStoreJwt();

    // 2. Reutilizar el grupo si ya existe en Apple con ese nombre (por
    //    ejemplo, de un intento anterior que falló a medias); si no, crearlo.
    const existingGroupsRes = await appStoreFetch(
      jwt,
      `/v1/apps/${appId}/subscriptionGroups?limit=200`,
    );
    const existingGroup = (existingGroupsRes.data ?? []).find(
      (g: any) => g.attributes?.referenceName === referenceName,
    );

    let groupId: string;
    if (existingGroup) {
      groupId = existingGroup.id;
    } else {
      const groupRes = await appStoreFetch(jwt, '/v1/subscriptionGroups', {
        method: 'POST',
        body: {
          data: {
            type: 'subscriptionGroups',
            attributes: { referenceName },
            relationships: { app: { data: { type: 'apps', id: appId } } },
          },
        },
      });
      groupId = groupRes.data.id;

      // 3. Crear una versión del grupo (para poder localizar el nombre)
      const versionRes = await appStoreFetch(jwt, '/v1/subscriptionGroupVersions', {
        method: 'POST',
        body: {
          data: {
            type: 'subscriptionGroupVersions',
            relationships: {
              subscriptionGroup: { data: { type: 'subscriptionGroups', id: groupId } },
            },
          },
        },
      });
      const versionId = versionRes.data.id;

      // 4. Localización del grupo
      await appStoreFetch(jwt, '/v2/subscriptionGroupLocalizations', {
        method: 'POST',
        body: {
          data: {
            type: 'subscriptionGroupLocalizations',
            attributes: { name: referenceName, locale: LOCALE },
            relationships: { version: { data: { type: 'subscriptionGroupVersions', id: versionId } } },
          },
        },
      });
    }

    // 5. Reutilizar la suscripción si ya existe en el grupo (reintentos);
    //    si no, crearla junto con su localización.
    const existingSubsRes = await appStoreFetch(
      jwt,
      `/v1/subscriptionGroups/${groupId}/subscriptions?limit=200`,
    );
    const existingSub = (existingSubsRes.data ?? []).find(
      (s: any) => s.attributes?.productId === productId,
    );

    let subscriptionId: string;
    if (existingSub) {
      subscriptionId = existingSub.id;
    } else {
      const subRes = await appStoreFetch(jwt, '/v1/subscriptions', {
        method: 'POST',
        body: {
          data: {
            type: 'subscriptions',
            attributes: {
              name: referenceName,
              productId,
              subscriptionPeriod: 'ONE_MONTH',
              familySharable: false,
            },
            relationships: { group: { data: { type: 'subscriptionGroups', id: groupId } } },
          },
        },
      });
      subscriptionId = subRes.data.id;

      // 6. Localización de la suscripción
      await appStoreFetch(jwt, '/v1/subscriptionLocalizations', {
        method: 'POST',
        body: {
          data: {
            type: 'subscriptionLocalizations',
            attributes: {
              name: plan.nombre,
              locale: LOCALE,
              description: `Suscripción ${plan.nombre} de ${nombreCreador} en Sinc.`,
            },
            relationships: { subscription: { data: { type: 'subscriptions', id: subscriptionId } } },
          },
        },
      });
    }

    // 6b. Declarar en qué territorio y con qué tipo de plan se ofrece la
    //     suscripción. Sin esto Apple rechaza el precio con
    //     "territory is not supported for your subscription and planType".
    //     Si ya existe (reintento), Apple responde 409 y seguimos.
    try {
      await appStoreFetch(jwt, '/v1/subscriptionPlanAvailabilities', {
        method: 'POST',
        body: {
          data: {
            type: 'subscriptionPlanAvailabilities',
            attributes: { planType: PLAN_TYPE, availableInNewTerritories: false },
            relationships: {
              subscription: { data: { type: 'subscriptions', id: subscriptionId } },
              availableTerritories: {
                data: TERRITORIES.map((id) => ({ type: 'territories', id })),
              },
            },
          },
        },
      });
    } catch (e) {
      if (!String(e).includes('-> 409')) throw e;
      console.warn('plan availability ya existía o conflicto 409, se continúa:', String(e));
    }

    // 7 y 8. Para cada territorio: buscar el price point más cercano al
    //    precio pedido y asignarlo como precio inicial.
    //    OJO: un territorio puede cobrar en USD en vez de BOB. Leemos la
    //    moneda real y convertimos el precio si hace falta.
    const prices: Record<string, { currency?: string; customerPrice: string }> = {};
    let usaPricePointId: string | null = null;

    for (const territory of TERRITORIES) {
      const pricePointsRes = await appStoreFetch(
        jwt,
        `/v1/subscriptions/${subscriptionId}/pricePoints?include=territory&filter[territory]=${territory}&limit=200`,
      );
      const pricePoints = pricePointsRes.data ?? [];
      if (!pricePoints.length) {
        throw new Error(`No hay price points disponibles para el territorio ${territory}`);
      }
      const currency: string | undefined = (pricePointsRes.included ?? []).find(
        (t: any) => t.type === 'territories' && t.id === territory,
      )?.attributes?.currency;

      let targetPrice = Number(plan.precio); // precio del creador, en Bs
      if (currency === 'USD') {
        const bobPerUsd = Number(Deno.env.get('APPSTORE_BOB_PER_USD') ?? '6.96');
        targetPrice = targetPrice / bobPerUsd;
      } else if (currency !== 'BOB') {
        throw new Error(
          `Moneda inesperada para ${territory}: ${currency}. No se asigna precio para evitar un monto equivocado.`,
        );
      }
      const chosenPricePoint = closestPricePoint(pricePoints, targetPrice);

      // startDate null = aplica de inmediato (precio inicial)
      try {
        await appStoreFetch(jwt, '/v1/subscriptionPrices', {
          method: 'POST',
          body: {
            data: {
              type: 'subscriptionPrices',
              attributes: { startDate: null, planType: PLAN_TYPE },
              relationships: {
                subscription: { data: { type: 'subscriptions', id: subscriptionId } },
                subscriptionPricePoint: {
                  data: { type: 'subscriptionPricePoints', id: chosenPricePoint.id },
                },
              },
            },
          },
        });
      } catch (e) {
        // Reintento: si el territorio ya tenía precio, Apple responde 409.
        // Un 409 por territorio NO habilitado sí es un error real.
        const msg = String(e);
        if (!msg.includes('-> 409') || msg.includes('UNSUPPORTED_TERRITORY')) throw e;
        console.warn(`precio de ${territory} ya existía o conflicto 409, se continúa:`, msg);
      }

      prices[territory] = { currency, customerPrice: chosenPricePoint.attributes.customerPrice };
      if (territory === 'USA') usaPricePointId = chosenPricePoint.id;
    }

    // 8b. La web de App Store Connect replica el precio base a TODOS los
    //     territorios; por API hay que hacerlo a mano. Sin precio en todos
    //     ellos, "Add for Review" falla con "You must add a subscription
    //     price". Usamos las equivalencias (equalizations) del precio de USA.
    const extraTerritories: string[] = [];
    const extraFailures: Record<string, string> = {};
    if (usaPricePointId) {
      const eqRes = await appStoreFetch(
        jwt,
        `/v1/subscriptionPricePoints/${usaPricePointId}/equalizations?include=territory&limit=200`,
      );
      const todo = (eqRes.data ?? []).filter((pp: any) => {
        const t = pp.relationships?.territory?.data?.id;
        return t && !TERRITORIES.includes(t);
      });
      const BATCH = 15;
      for (let i = 0; i < todo.length; i += BATCH) {
        await Promise.all(todo.slice(i, i + BATCH).map(async (pp: any) => {
        const terr: string = pp.relationships.territory.data.id;
        try {
          await appStoreFetch(jwt, '/v1/subscriptionPrices', {
            method: 'POST',
            body: {
              data: {
                type: 'subscriptionPrices',
                attributes: { startDate: null, planType: PLAN_TYPE },
                relationships: {
                  subscription: { data: { type: 'subscriptions', id: subscriptionId } },
                  subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: pp.id } },
                },
              },
            },
          });
          extraTerritories.push(terr);
        } catch (e) {
          const msg = String(e);
          if (msg.includes('-> 409') && !msg.includes('UNSUPPORTED_TERRITORY')) {
            extraTerritories.push(terr); // ya tenía precio
          } else {
            extraFailures[terr] = msg.slice(0, 200);
          }
        }
        }));
      }
    }

    // 9. Guardar referencias en la base de datos
    await admin
      .from('plan_suscripcion')
      .update({
        apple_subscription_group_id: groupId,
        apple_product_id: productId,
        apple_status: 'pending', // queda pendiente de revisión de Apple
      })
      .eq('id_plan', id_plan);

    return json({
      success: true,
      productId,
      subscriptionGroupId: groupId,
      prices,
      extraTerritoriesPriced: extraTerritories.length,
      extraFailures,
      requestedPriceBs: Number(plan.precio),
      note: 'Creado en App Store Connect. Queda en estado "Waiting for Review" hasta que Apple lo apruebe -- no está disponible para comprar todavía.',
    });
  } catch (e) {
    console.error('create-iap-subscription: error:', e);
    return json({ error: String(e) }, 500);
  }
});
