// Edge Function: delete-account
//
// Borra permanentemente al usuario autenticado y todo lo que le pertenece,
// usando el esquema real de Sinc (tablas: usuario, creador, publicacion,
// multimedia, comentario, me_gusta, chat, participante_chat, mensaje,
// mensaje_multimedia, suscripcion, transaccion, plan_suscripcion).
//
// Requiere SERVICE_ROLE_KEY porque el cliente nunca tiene permiso para
// borrar de auth.users. SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
// los inyecta Supabase automáticamente en cada Edge Function (no hay que
// configurarlos como secret).
//
// Deploy manual (igual que vpay-*): Supabase Dashboard -> Edge Functions ->
// New function -> nómbrala "delete-account" -> pega este archivo -> Deploy.
//
// Regla de negocio: si el usuario es creador y tiene suscriptores con una
// suscripción activa, bloqueamos el borrado (409) para no dejar a otros
// usuarios con una suscripción pagada apuntando a un creador que ya no
// existe. En ese caso deben contactar soporte.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json(401, { error: 'Missing Authorization header' });

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    // Cliente con el JWT del usuario: solo para saber quién es, de forma segura.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return json(401, { error: 'Invalid or expired session' });
    }

    const userId = user.id;

    // Cliente admin (service role): bypassa RLS, borra lo que sea necesario.
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // 1. ¿Es creador?
    const { data: creadorRow } = await admin
      .from('creador')
      .select('id_creador')
      .eq('id_creador', userId)
      .maybeSingle();
    const esCreador = !!creadorRow;

    // 2. Si es creador, bloquear si tiene suscriptores con suscripción activa.
    if (esCreador) {
      const nowIso = new Date().toISOString();
      const { count } = await admin
        .from('suscripcion')
        .select('id_suscripcion', { count: 'exact', head: true })
        .eq('id_creador', userId)
        .or(`fecha_fin.is.null,fecha_fin.gt.${nowIso}`);

      if ((count ?? 0) > 0) {
        return json(409, {
          error:
            'No puedes eliminar tu cuenta de creador mientras tengas suscriptores activos. Contacta a soporte para gestionar el cierre de tu cuenta.',
        });
      }
    }

    // 3. Recolectar ids relacionados que se necesitan para las tablas hijas.
    const { data: chatsRaw } = await admin
      .from('chat')
      .select('id_chat')
      .or(`creado_por.eq.${userId},id_creador.eq.${userId}`);
    const chatIds = (chatsRaw ?? []).map((c) => c.id_chat as string);

    const { data: publicacionesRaw } = esCreador
      ? await admin.from('publicacion').select('id_publicacion').eq('id_creador', userId)
      : { data: [] as { id_publicacion: string }[] };
    const publicacionIds = (publicacionesRaw ?? []).map((p) => p.id_publicacion as string);

    // mensajes que hay que borrar: los que envió el usuario + los de sus chats
    const mensajeOr = [`id_remitente.eq.${userId}`];
    if (chatIds.length) mensajeOr.push(`id_chat.in.(${chatIds.join(',')})`);
    const { data: mensajesRaw } = await admin
      .from('mensaje')
      .select('id_mensaje')
      .or(mensajeOr.join(','));
    const mensajeIds = (mensajesRaw ?? []).map((m) => m.id_mensaje as string);

    // 4. Borrar de hijos hacia padres.
    if (mensajeIds.length) {
      await admin.from('mensaje_multimedia').delete().in('id_mensaje', mensajeIds);
    }

    if (publicacionIds.length) {
      await admin.from('multimedia').delete().in('id_publicacion', publicacionIds);
    }

    {
      const or = [`id_usuario.eq.${userId}`];
      if (publicacionIds.length) or.push(`id_publicacion.in.(${publicacionIds.join(',')})`);
      const filter = or.join(',');
      await admin.from('comentario').delete().or(filter);
      await admin.from('me_gusta').delete().or(filter);
    }

    await admin.from('mensaje').delete().or(mensajeOr.join(','));

    {
      const or = [`id_usuario.eq.${userId}`];
      if (chatIds.length) or.push(`id_chat.in.(${chatIds.join(',')})`);
      await admin.from('participante_chat').delete().or(or.join(','));
    }

    if (chatIds.length) {
      await admin.from('chat').delete().in('id_chat', chatIds);
    }

    await admin.from('suscripcion').delete().or(`id_usuario.eq.${userId},id_creador.eq.${userId}`);
    await admin.from('transaccion').delete().or(`id_usuario.eq.${userId},id_creador.eq.${userId}`);

    if (esCreador) {
      await admin.from('plan_suscripcion').delete().eq('id_creador', userId);
      await admin.from('creador').delete().eq('id_creador', userId);
    }

    const { error: deleteUsuarioError } = await admin
      .from('usuario')
      .delete()
      .eq('id_usuario', userId);
    if (deleteUsuarioError) {
      console.error('delete-account: error borrando de usuario:', deleteUsuarioError.message);
    }

    // 5. Por último, borrar el usuario de auth.users (invalida su sesión).
    const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      return json(500, {
        error: `No se pudo borrar el usuario de auth: ${deleteUserError.message}`,
      });
    }

    return json(200, { success: true });
  } catch (e) {
    console.error('delete-account: unhandled error:', e);
    return json(500, { error: String(e) });
  }
});
