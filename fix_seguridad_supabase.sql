-- =====================================================================
-- FIX DE SEGURIDAD — Sinc (Supabase)
-- Corre esto completo en el SQL Editor. Está dividido en bloques
-- comentados; puedes correrlo todo de una vez o bloque por bloque.
-- Revisé el código Flutter para confirmar qué tablas se consultan
-- directamente desde el cliente (from('...')) y cuáles solo se tocan
-- vía funciones RPC / Edge Functions — las políticas de abajo están
-- escritas para no romper nada de lo que ya funciona.
-- =====================================================================


-- =====================================================================
-- 1) TABLAS QUE SOLO SE TOCAN DESDE FUNCIONES SECURITY DEFINER O DESDE
--    LAS EDGE FUNCTIONS (SERVICE ROLE). El cliente Flutter nunca las
--    consulta directo (confirmado por grep en todo lib/). Activar RLS
--    sin políticas las deja en "default deny" para la anon/authenticated
--    key, exactamente igual que ya tienes hoy en admin_user y vpay_tokens.
--    Nada de lo que usa tu app hoy se rompe con esto.
-- =====================================================================

ALTER TABLE public.categoria           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comentario          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creador             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.me_gusta            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.metodo_pago         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.multimedia          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participante_chat   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_suscripcion    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.publicacion         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensaje_multimedia  ENABLE ROW LEVEL SECURITY;

-- Nota: si en el futuro quieres que el cliente pueda leer directamente
-- catálogos no sensibles (categoria, plan_suscripcion, metodo_pago),
-- ahí sí tendría sentido un simple:
--   CREATE POLICY "lectura publica" ON public.categoria FOR SELECT USING (true);
-- Por ahora no hace falta porque todo pasa por obtener_creadores() etc.


-- =====================================================================
-- 2) TRANSACCION: nadie la consulta directo hoy desde Flutter, pero le
--    agrego una política de lectura de "mis propias transacciones" para
--    cuando construyas una pantalla de historial de pagos. Insert/Update
--    quedan cerrados: eso solo debe pasar por create_transaction()
--    (RPC) y por las Edge Functions con service role.
-- =====================================================================

ALTER TABLE public.transaccion ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leer mis propias transacciones"
ON public.transaccion
FOR SELECT
USING (auth.uid() = id_usuario);


-- =====================================================================
-- 3) USUARIO: tu código hace insert/select/update siempre filtrando por
--    id_usuario = auth.uid() (confirmado en auth.datasource.dart). Estas
--    políticas cubren exactamente ese uso real.
-- =====================================================================

ALTER TABLE public.usuario ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leer mi propio perfil"
ON public.usuario
FOR SELECT
USING (auth.uid() = id_usuario);

CREATE POLICY "Crear mi propio perfil"
ON public.usuario
FOR INSERT
WITH CHECK (auth.uid() = id_usuario);

CREATE POLICY "Actualizar mi propio perfil"
ON public.usuario
FOR UPDATE
USING (auth.uid() = id_usuario)
WITH CHECK (auth.uid() = id_usuario);


-- =====================================================================
-- 4) CHAT: OJO — esta es la única tabla donde tu código actual
--    (ChatDataSource.getOrCreateComunidadChatCreador) no filtra por
--    auth.uid() en ningún lado: hace SELECT por id_creador sin más, e
--    INSERT solo con {id_creador} (creado_por queda null). No puedo
--    escribir una política "solo el dueño" sin romper esa función tal
--    como está hoy. Dejo algo funcional pero te recomiendo migrar ese
--    flujo a la RPC get_or_create_chat_por_plan (que sí valida plan y,
--    después del fix del punto 7, también la suscripción activa) y
--    borrar este acceso directo a la tabla.
-- =====================================================================

ALTER TABLE public.chat ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Ver chats donde participo o soy el creador"
ON public.chat
FOR SELECT
USING (
  auth.uid() = creado_por
  OR auth.uid() = id_creador
  OR EXISTS (
    SELECT 1 FROM public.participante_chat pc
    WHERE pc.id_chat = chat.id_chat AND pc.id_usuario = auth.uid()
  )
);

-- Cualquier usuario autenticado puede crear una fila de chat (igual que
-- hoy, sin filtro). Esto es intencionalmente permisivo para no romper
-- getOrCreateComunidadChatCreador; ciérralo más cuando migres a la RPC.
CREATE POLICY "Crear chat autenticado"
ON public.chat
FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);


-- =====================================================================
-- 5) SUSCRIPCION: ya tenías las políticas correctas escritas
--    ("Leer suscripciones propias", "Permitir insertar si usuario
--    autenticado") — el problema era solo que RLS estaba apagado.
--    Con esto se activan y empiezan a aplicarse.
-- =====================================================================

ALTER TABLE public.suscripcion ENABLE ROW LEVEL SECURITY;
-- Las políticas ya existen, no hace falta recrearlas.


-- =====================================================================
-- 6) MENSAJE: borrar la política que anulaba todo lo demás.
-- =====================================================================

DROP POLICY IF EXISTS "allow all insert" ON public.mensaje;

-- Con esto, el único INSERT permitido queda gobernado por
-- insert_mensaje_dm_o_solo_creador_en_group, que ya está bien escrita.


-- =====================================================================
-- 7) FUNCIONES: recreo las 5 funciones con los fixes de seguridad.
--    Uso CREATE OR REPLACE así que conservan permisos/dependencias.
-- =====================================================================

-- 7a) enviar_mensaje: usar auth.uid() en vez de un id_remitente que
--     manda el cliente (eso permitía enviar mensajes suplantando a
--     otra persona).
CREATE OR REPLACE FUNCTION public.enviar_mensaje(
  id_chat_param uuid,
  contenido_param text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Unauthorized';
  end if;

  insert into mensaje (id_chat, id_remitente, contenido)
  values (id_chat_param, auth.uid(), contenido_param);
end;
$function$;

-- ⚠️ Esta función cambia de firma (ya no recibe id_remitente_param).
-- Tendrás que actualizar la llamada en Flutter (chat.datasource.dart /
-- supabase_datasource.dart) para dejar de mandar ese parámetro.
-- Si prefieres no tocar Flutter todavía, dime y te dejo una versión
-- que mantenga el parámetro pero lo ignore (menos limpio, pero no
-- requiere cambios inmediatos en la app).


-- 7b) create_transaction: validar que el plan pertenezca al creador y
--     usar el precio real de plan_suscripcion en vez del monto que
--     manda el cliente.
CREATE OR REPLACE FUNCTION public.create_transaction(
  p_id_creador uuid,
  p_id_plan uuid
)
RETURNS transaccion
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  new_transaction public.transaccion;
  v_precio numeric;
BEGIN
  SELECT precio INTO v_precio
  FROM public.plan_suscripcion
  WHERE id_plan = p_id_plan
    AND id_creador = p_id_creador;

  IF v_precio IS NULL THEN
    RAISE EXCEPTION 'Plan no válido para este creador';
  END IF;

  INSERT INTO public.transaccion (
    id_usuario,
    id_creador,
    id_plan,
    monto,
    estado
  )
  VALUES (
    auth.uid(),
    p_id_creador,
    p_id_plan,
    v_precio,
    'PEN'
  )
  RETURNING * INTO new_transaction;

  RETURN new_transaction;
END;
$function$;

-- ⚠️ Esta función también cambia de firma: ya no recibe p_monto (el
-- precio ahora se calcula siempre del lado servidor, que es justo el
-- fix). Actualiza la llamada en Flutter para dejar de mandar p_monto.


-- 7c) get_or_create_chat_por_plan: exigir suscripción activa antes de
--     dejar entrar al chat, y exigir que quien llama sea una de las dos
--     partes (el propio suscriptor o el creador del plan) en vez de
--     confiar en p_id_usuario a ciegas. Mantengo la firma original
--     (con p_id_usuario) porque tu código la usa tanto para "el
--     suscriptor abre su chat" como para "el creador abre el chat con
--     un suscriptor puntual" (ver isCreator en chat.datasource.dart) —
--     no hace falta tocar Flutter para esta función.
CREATE OR REPLACE FUNCTION public.get_or_create_chat_por_plan(
  p_id_usuario uuid,
  p_id_creador uuid,
  p_id_plan uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_chat_id uuid;
  v_plan_nombre text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 0) quien llama debe ser el propio suscriptor o el propio creador,
  --    nunca un tercero actuando en nombre de otros dos usuarios
  IF auth.uid() <> p_id_usuario AND auth.uid() <> p_id_creador THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  -- 1) obtener nombre del plan (Comunidad/Fellow) y validar que sea del creador
  SELECT lower(nombre)
    INTO v_plan_nombre
  FROM plan_suscripcion
  WHERE id_plan = p_id_plan
    AND id_creador = p_id_creador;

  IF v_plan_nombre IS NULL THEN
    RAISE EXCEPTION 'Plan no válido para este creador';
  END IF;

  -- 2) exigir suscripción activa del suscriptor (esto es lo que faltaba)
  IF NOT EXISTS (
    SELECT 1 FROM suscripcion
    WHERE id_usuario = p_id_usuario
      AND id_plan = p_id_plan
      AND (fecha_fin IS NULL OR fecha_fin > now())
  ) THEN
    RAISE EXCEPTION 'No hay una suscripción activa a este plan';
  END IF;

  -- 3) COMUNIDAD => chat grupal del creador
  IF v_plan_nombre = 'comunidad' THEN
    SELECT id_chat INTO v_chat_id
    FROM chat
    WHERE tipo = 'group'
      AND id_creador = p_id_creador
      AND id_plan = p_id_plan
    LIMIT 1;

    IF v_chat_id IS NULL THEN
      INSERT INTO chat (tipo, nombre, creado_por, id_creador, id_plan)
      VALUES ('group', 'Comunidad', p_id_creador, p_id_creador, p_id_plan)
      RETURNING id_chat INTO v_chat_id;
    END IF;

    INSERT INTO participante_chat (id_chat, id_usuario)
    VALUES (v_chat_id, p_id_usuario)
    ON CONFLICT (id_chat, id_usuario) DO NOTHING;

    RETURN v_chat_id;
  END IF;

  -- 4) FELLOW (u otros) => DM 1:1
  SELECT pc1.id_chat INTO v_chat_id
  FROM participante_chat pc1
  JOIN participante_chat pc2 ON pc1.id_chat = pc2.id_chat
  JOIN chat ch ON ch.id_chat = pc1.id_chat
  WHERE ch.tipo = 'dm'
    AND pc1.id_usuario = p_id_usuario
    AND pc2.id_usuario = p_id_creador
  LIMIT 1;

  IF v_chat_id IS NOT NULL THEN
    RETURN v_chat_id;
  END IF;

  INSERT INTO chat (tipo, creado_por)
  VALUES ('dm', p_id_usuario)
  RETURNING id_chat INTO v_chat_id;

  INSERT INTO participante_chat (id_chat, id_usuario)
  VALUES (v_chat_id, p_id_usuario);

  INSERT INTO participante_chat (id_chat, id_usuario)
  VALUES (v_chat_id, p_id_creador);

  RETURN v_chat_id;
END;
$function$;

-- Esta sí mantiene la firma original: no hace falta editar Flutter.


-- 7d) get_ganancias_creador_mes_v1: forzar p_id_creador = auth.uid().
CREATE OR REPLACE FUNCTION public.get_ganancias_creador_mes_v1(
  p_year integer,
  p_month integer
)
RETURNS TABLE(anio integer, mes integer, total_bruto numeric, fee numeric, balance numeric, comunidad_monto numeric, comunidad_suscriptores integer, fellow_monto numeric, tips_monto numeric, contenido_solicitado_monto numeric)
LANGUAGE sql
SECURITY DEFINER
AS $function$
with rango as (
  select
    make_date(p_year, p_month, 1) as inicio,
    (make_date(p_year, p_month, 1) + interval '1 month') as fin
),
pagos as (
  select
    t.monto,
    lower(p.nombre) as plan_nombre
  from transaccion t
  join rango r on true
  left join plan_suscripcion p on p.id_plan = t.id_plan
  where t.id_creador = auth.uid()
    and t.estado = 'PAG'
    and t.fecha_transaccion >= r.inicio
    and t.fecha_transaccion < r.fin
),
agg as (
  select
    coalesce(sum(monto), 0) as total_bruto,
    count(*) as total_transacciones,
    coalesce(sum(case when plan_nombre = 'comunidad' then monto end), 0) as comunidad_monto,
    coalesce(sum(case when plan_nombre = 'fellow' then monto end), 0) as fellow_monto,
    count(*) filter (where plan_nombre = 'comunidad') as comunidad_suscriptores
  from pagos
)
select
  p_year as anio,
  p_month as mes,
  a.total_bruto,
  round((a.total_bruto * 0.10) + (a.total_transacciones * 1), 2) as fee,
  (a.total_bruto - round((a.total_bruto * 0.10) + (a.total_transacciones * 1), 2)) as balance,
  a.comunidad_monto,
  a.comunidad_suscriptores,
  a.fellow_monto,
  0::numeric as tips_monto,
  0::numeric as contenido_solicitado_monto
from agg a;
$function$;

-- 7e) get_top_pagos_creador_mes_v1: idem.
CREATE OR REPLACE FUNCTION public.get_top_pagos_creador_mes_v1(
  p_year integer,
  p_month integer,
  p_limit integer DEFAULT 10
)
RETURNS TABLE(id_usuario uuid, nombre_usuario text, total_pagado numeric)
LANGUAGE sql
SECURITY DEFINER
AS $function$
with rango as (
  select
    make_date(p_year, p_month, 1) as inicio,
    (make_date(p_year, p_month, 1) + interval '1 month') as fin
)
select
  u.id_usuario,
  u.nombre_usuario,
  coalesce(sum(t.monto),0) as total_pagado
from transaccion t
join usuario u on u.id_usuario = t.id_usuario
join rango r on true
where t.id_creador = auth.uid()
  and t.estado = 'PAG'
  and t.fecha_transaccion >= r.inicio
  and t.fecha_transaccion < r.fin
group by u.id_usuario, u.nombre_usuario
order by total_pagado desc
limit p_limit;
$function$;

-- 7f) get_creadores_por_tipo: forzar p_user_id = auth.uid().
CREATE OR REPLACE FUNCTION public.get_creadores_por_tipo(
  p_tipo text
)
RETURNS TABLE(id_creador uuid, id_plan uuid, nombre_creador text, bio text, precio_plan numeric, tipo_plan text, fecha_inicio timestamp without time zone)
LANGUAGE sql
SECURITY DEFINER
AS $function$
  SELECT
    c.id_creador,
    p.id_plan,
    u.nombre_usuario AS nombre_creador,
    c.bio,
    p.precio AS precio_plan,
    p.nombre AS tipo_plan,
    s.fecha_inicio
  FROM suscripcion s
  INNER JOIN creador c
      ON c.id_creador = s.id_creador
  INNER JOIN usuario u
      ON u.id_usuario = c.id_creador
  INNER JOIN plan_suscripcion p
      ON p.id_plan = s.id_plan
  WHERE s.id_usuario = auth.uid()
    AND (
      p_tipo = 'todos'
      OR lower(p.nombre) = lower(p_tipo)
    );
$function$;

-- ⚠️ Las 4 funciones de 7d/7e/7f cambian de firma (pierden el parámetro
-- de id). Actualiza las llamadas correspondientes en
-- analytics.datasources.dart y creator.datasource.dart.


-- =====================================================================
-- 8) Opcional pero recomendado: restringir el valor de transaccion.estado
--    a los valores reales que usa el código (PEN, PAG, y los que uses
--    para rechazado/anulado — ajusta la lista si usas otros).
-- =====================================================================

ALTER TABLE public.transaccion
  ADD CONSTRAINT transaccion_estado_check
  CHECK (estado IN ('PEN', 'PAG', 'REV', 'ANU'));

-- Si tienes filas existentes con otro valor de `estado`, este ALTER
-- va a fallar — en ese caso avísame y lo ajustamos.


-- =====================================================================
-- 9) FIX (encontrado probando mensajes en un chat Fellow/DM): faltaba
--    una política de SELECT en participante_chat.
--
--    En el punto 1 activamos RLS en participante_chat sin políticas,
--    asumiendo que nadie la consultaba directo desde el cliente. El
--    problema es que la política de INSERT de `mensaje`
--    (insert_mensaje_dm_o_solo_creador_en_group) hace una subconsulta
--    a participante_chat para verificar que seas parte del chat — y esa
--    subconsulta corre con los permisos del usuario que llama, así que
--    también queda sujeta a RLS. Sin ninguna política de SELECT ahí,
--    la subconsulta siempre "ve" cero filas, así que la condición
--    fallaba para todos, aunque la fila sí existiera en la tabla.
--
--    Lo mismo afectaba a la política de SELECT de `chat` (punto 4 del
--    bloque anterior): el segundo participante de un DM —el que no lo
--    creó— tampoco iba a poder ver ese chat, por la misma razón.
--
--    Solo con esto se soluciona: cada quien puede ver su propia fila
--    de participante_chat (que es exactamente lo que ambas políticas
--    necesitan comprobar).
-- =====================================================================

CREATE POLICY "Ver mi propia fila de participante"
ON public.participante_chat
FOR SELECT
USING (auth.uid() = id_usuario);


-- =====================================================================
-- 10) FIX (encontrado al probar "ver creadores" como usuario normal):
--     obtener_creadores() y obtener_chats_suscritos() NO son
--     SECURITY DEFINER. Antes esto no importaba porque RLS estaba
--     apagado en todas las tablas que tocan (creador, categoria,
--     plan_suscripcion, publicacion, usuario, chat, participante_chat).
--     Ahora que esas tablas tienen RLS, estas dos funciones corren con
--     los permisos del usuario que llama y las políticas de "usuario"
--     ("solo mi propio perfil") les bloquean ver el nombre/perfil de
--     cualquier OTRO usuario (el creador). Por eso obtener_creadores()
--     empezó a devolver vacío para un usuario normal.
--
--     Las hacemos SECURITY DEFINER, igual que el resto de funciones de
--     "listado" (get_creadores_por_tipo, get_mis_suscriptores_por_tipo).
--     obtener_creadores() ya filtraba internamente `es_publico = true`
--     para publicaciones, así que sigue sin exponer contenido privado.
--     De paso, en obtener_chats_suscritos quitamos el parámetro
--     id_usuario_input y usamos auth.uid(), por la misma razón que las
--     demás funciones de este archivo (no confiar en un id que manda
--     el cliente).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.obtener_creadores()
RETURNS TABLE(id_usuario uuid, nombre_usuario text, email text, bio text, categoria text, planes json, publicaciones json)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $function$
  SELECT
    u.id_usuario,
    u.nombre_usuario,
    u.email,
    c.bio,
    cat.nombre AS categoria,

    (
      SELECT json_agg(
        json_build_object(
          'id_plan', p.id_plan,
          'nombre', p.nombre,
          'descripcion', p.descripcion,
          'precio', p.precio
        )
        ORDER BY p.precio
      )
      FROM plan_suscripcion p
      WHERE p.id_creador = c.id_creador
    ) AS planes,

    (
      SELECT json_agg(row_to_json(p))
      FROM (
        SELECT
          pub.id_publicacion,
          pub.titulo,
          pub.contenido,
          pub.es_publico,
          pub.fecha_publicacion,
          (
            SELECT COUNT(*)
            FROM me_gusta mg
            WHERE mg.id_publicacion = pub.id_publicacion
          ) AS cantidad_likes
        FROM publicacion pub
        WHERE pub.id_creador = c.id_creador
          AND pub.es_publico = true
        ORDER BY pub.fecha_publicacion DESC
      ) p
    ) AS publicaciones

  FROM creador c
  JOIN usuario u
      ON u.id_usuario = c.id_creador
  LEFT JOIN categoria cat
      ON c.id_categoria = cat.id_categoria;
$function$;

CREATE OR REPLACE FUNCTION public.obtener_chats_suscritos()
RETURNS TABLE(id_chat uuid, id_creador uuid, nombre_creador text)
LANGUAGE sql
SECURITY DEFINER
AS $function$
  select
    c.id_chat,
    c.creado_por as id_creador,
    u.nombre_usuario as nombre_creador
  from chat c
  join participante_chat p on p.id_chat = c.id_chat
  join usuario u on u.id_usuario = c.creado_por
  join suscripcion s on s.id_creador = c.creado_por and s.id_usuario = auth.uid()
  where p.id_usuario = auth.uid()
$function$;

-- ⚠️ obtener_chats_suscritos cambia de firma (ya no recibe
-- id_usuario_input). Actualicé las llamadas en chat.datasource.dart y
-- supabase_datasource.dart.


-- =====================================================================
-- 11) FIX (corrección de un error mío en el punto 7a): enviar_mensaje
--     no debería ser SECURITY DEFINER.
--
--     La dejé como SECURITY DEFINER pensando que necesitaba permisos
--     extra, pero eso hace que se salte por completo la política de
--     `mensaje` que valida que seas participante del chat o el
--     creador (insert_mensaje_dm_o_solo_creador_en_group) — la función
--     solo comprobaba que hubiera alguien autenticado, no que
--     perteneciera al chat. Es decir, dejaba mandar mensajes a
--     cualquier chat. Ahora que participante_chat ya tiene su política
--     de lectura (punto 9), la RLS de `mensaje` funciona correctamente
--     por sí sola — no hace falta bypasearla.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.enviar_mensaje(
  id_chat_param uuid,
  contenido_param text
)
RETURNS void
LANGUAGE plpgsql
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Unauthorized';
  end if;

  insert into mensaje (id_chat, id_remitente, contenido)
  values (id_chat_param, auth.uid(), contenido_param);
end;
$function$;


-- =====================================================================
-- 12) FIX (encontrado al probar Comunidad con una suscripción vencida):
--     `esta_suscrito` y la comprobación de "estoy suscrito a este plan"
--     solo miraban si existía una fila en `suscripcion`, sin fijarse en
--     `fecha_fin`. Como `get_or_create_chat_por_plan` sí exige que la
--     suscripción esté vigente (fix del punto 3), un usuario con una
--     suscripción vencida veía en la UI "sí estás suscrito" pero al
--     abrir el chat se lo rechazaba con un error crudo, en vez de
--     mandarlo a re-suscribirse. Alineamos ambas comprobaciones.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.esta_suscrito(p_id_usuario uuid, p_id_creador uuid)
 RETURNS boolean
 LANGUAGE sql
AS $function$
  select exists (
    select 1
    from Suscripcion
    where id_usuario = p_id_usuario
      and id_creador = p_id_creador
      and (fecha_fin is null or fecha_fin > now())
  );
$function$;

-- Nueva función para reemplazar la consulta directa a la tabla
-- `suscripcion` que hacía esSuscriptorDePlan (esa consulta tampoco
-- miraba fecha_fin). Usa auth.uid(), no confía en un id del cliente.
CREATE OR REPLACE FUNCTION public.esta_suscrito_a_plan(p_id_plan uuid)
 RETURNS boolean
 LANGUAGE sql
AS $function$
  select exists (
    select 1
    from suscripcion
    where id_usuario = auth.uid()
      and id_plan = p_id_plan
      and (fecha_fin is null or fecha_fin > now())
  );
$function$;

-- ⚠️ Actualicé PaymentDataSource.esSuscriptorDePlan en Flutter para que
-- llame a este nuevo RPC en vez de consultar la tabla directamente.


-- =====================================================================
-- 13) FIX (encontrado al ver un creador repetido dos veces en Fellow):
--     no hay ninguna restricción que impida tener más de una fila en
--     `suscripcion` para el mismo (id_usuario, id_creador, id_plan) —
--     por ejemplo, de las pruebas manuales que hicimos por SQL más una
--     suscripción real después. Las funciones que listan "mis
--     creadores/fellows" y "mis suscriptores" hacen JOIN contra
--     suscripcion sin eliminar duplicados, así que si hay 2 filas, la
--     fila del creador (o del suscriptor) sale repetida en la lista.
--
--     Arreglo con DISTINCT ON (se queda con la suscripción más
--     reciente por creador/plan) y de paso excluyo las que ya vencieron
--     (mismo criterio de "activa" que usamos en el resto del archivo).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.get_creadores_por_tipo(
  p_tipo text
)
RETURNS TABLE(id_creador uuid, id_plan uuid, nombre_creador text, bio text, precio_plan numeric, tipo_plan text, fecha_inicio timestamp without time zone)
LANGUAGE sql
SECURITY DEFINER
AS $function$
  SELECT DISTINCT ON (c.id_creador, p.id_plan)
    c.id_creador,
    p.id_plan,
    u.nombre_usuario AS nombre_creador,
    c.bio,
    p.precio AS precio_plan,
    p.nombre AS tipo_plan,
    s.fecha_inicio
  FROM suscripcion s
  INNER JOIN creador c
      ON c.id_creador = s.id_creador
  INNER JOIN usuario u
      ON u.id_usuario = c.id_creador
  INNER JOIN plan_suscripcion p
      ON p.id_plan = s.id_plan
  WHERE s.id_usuario = auth.uid()
    AND (s.fecha_fin IS NULL OR s.fecha_fin > now())
    AND (
      p_tipo = 'todos'
      OR lower(p.nombre) = lower(p_tipo)
    )
  ORDER BY c.id_creador, p.id_plan, s.fecha_inicio DESC;
$function$;

CREATE OR REPLACE FUNCTION public.get_mis_suscriptores_por_tipo(p_tipo text)
RETURNS TABLE(id_usuario uuid, nombre_usuario text, email text, id_plan uuid, tipo_plan text, precio_plan numeric, fecha_inicio timestamp without time zone, fecha_fin timestamp without time zone)
LANGUAGE sql
SECURITY DEFINER
AS $function$
  SELECT DISTINCT ON (u.id_usuario, p.id_plan)
    u.id_usuario,
    u.nombre_usuario,
    u.email,
    p.id_plan,
    p.nombre AS tipo_plan,
    p.precio AS precio_plan,
    s.fecha_inicio,
    s.fecha_fin
  FROM suscripcion s
  JOIN usuario u ON u.id_usuario = s.id_usuario
  JOIN plan_suscripcion p ON p.id_plan = s.id_plan
  WHERE s.id_creador = auth.uid()
    AND EXISTS (SELECT 1 FROM creador c WHERE c.id_creador = auth.uid())
    AND (s.fecha_fin IS NULL OR s.fecha_fin > now())
    AND (
      lower(p_tipo) = 'todos'
      OR lower(p.nombre) = lower(p_tipo)
    )
  ORDER BY u.id_usuario, p.id_plan, s.fecha_inicio DESC;
$function$;

CREATE OR REPLACE FUNCTION public.obtener_chats_suscritos()
RETURNS TABLE(id_chat uuid, id_creador uuid, nombre_creador text)
LANGUAGE sql
SECURITY DEFINER
AS $function$
  select distinct on (c.id_chat)
    c.id_chat,
    c.creado_por as id_creador,
    u.nombre_usuario as nombre_creador
  from chat c
  join participante_chat p on p.id_chat = c.id_chat
  join usuario u on u.id_usuario = c.creado_por
  join suscripcion s on s.id_creador = c.creado_por and s.id_usuario = auth.uid()
  where p.id_usuario = auth.uid()
    and (s.fecha_fin is null or s.fecha_fin > now())
$function$;

-- Opcional pero recomendado para que esto no vuelva a pasar: evitar que
-- se puedan crear dos filas de suscripción para el mismo (usuario, plan).
--
-- Postgres no deja usar now() en la condición de un índice parcial (el
-- error "functions in index predicate must be marked IMMUTABLE" es
-- justamente eso), así que en vez de un índice parcial "solo activas",
-- hacemos uno normal sobre toda la tabla. Tiene sentido: tu propio
-- callback-vpay ya busca la fila existente (esté vencida o no, ordena
-- por fecha_fin y toma la más reciente) y le extiende fecha_fin en vez
-- de insertar una fila nueva — o sea, en el flujo real nunca debería
-- haber más de una fila por (usuario, plan), vencida o no.
-- Antes de crear el índice: revisa qué duplicados hay (por si quieres
-- verlos antes de borrar algo).
SELECT id_suscripcion, id_usuario, id_creador, id_plan, fecha_inicio, fecha_fin
FROM suscripcion
WHERE (id_usuario, id_plan) IN (
  SELECT id_usuario, id_plan FROM suscripcion
  GROUP BY id_usuario, id_plan
  HAVING COUNT(*) > 1
)
ORDER BY id_usuario, id_plan, fecha_inicio DESC;

-- Limpieza: por cada (id_usuario, id_plan) duplicado, se queda solo con
-- la fila de fecha_inicio más reciente y borra el resto. Cubre todos
-- los duplicados que haya, no solo el que reportó el error.
DELETE FROM suscripcion s
WHERE s.id_suscripcion NOT IN (
  SELECT DISTINCT ON (id_usuario, id_plan) id_suscripcion
  FROM suscripcion
  ORDER BY id_usuario, id_plan, fecha_inicio DESC
);

-- Ahora sí, el índice único (esto ya no debería fallar):
CREATE UNIQUE INDEX IF NOT EXISTS suscripcion_usuario_plan_unica
  ON public.suscripcion (id_usuario, id_plan);
