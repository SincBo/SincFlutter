-- ============================================================
-- Seed de cuentas demo para el reviewer de Apple (Guideline 2.1a)
-- ============================================================
-- Apple necesita loguearse con email + contraseña y ver contenido real
-- sin pagar. No sirven cuentas de Google/Apple Sign-In (el reviewer no
-- puede iniciar sesión con TU cuenta de Google), así que las dos cuentas
-- demo deben crearse con email + contraseña.
--
-- PASO 1 — Crea las dos cuentas DESDE LA APP (pantalla "Registro"),
-- con email + contraseña normal:
--   - demo.creador@sincbo.app   (cualquier contraseña segura)
--   - demo.fan@sincbo.app       (esta es la que le das a Apple)
--
-- PASO 2 — Corre esto para confirmar que existen y copiar sus IDs:
--   select id_usuario, email from usuario where email in
--     ('demo.creador@sincbo.app', 'demo.fan@sincbo.app');
--
-- PASO 3 — Pega esos dos UUID abajo en el bloque DO $$ ... $$ y corre
-- todo el bloque UNA sola vez en el SQL Editor de Supabase.
-- ============================================================

DO $$
DECLARE
  demo_creador_id  uuid := 'PEGA-AQUI-EL-UUID-DE-demo.creador@sincbo.app';
  demo_fan_id      uuid := 'PEGA-AQUI-EL-UUID-DE-demo.fan@sincbo.app';
  id_plan_comunidad uuid;
  id_plan_fellow    uuid;
  id_chat_comunidad uuid;
  id_chat_fellow    uuid;
BEGIN
  -- Marcar la cuenta demo.creador como creador
  UPDATE usuario SET es_creador = true WHERE id_usuario = demo_creador_id;

  INSERT INTO creador (id_creador, bio)
  VALUES (demo_creador_id, 'Cuenta de demostración para revisión de Apple.')
  ON CONFLICT (id_creador) DO NOTHING;

  -- Planes del creador demo
  INSERT INTO plan_suscripcion (nombre, descripcion, precio, id_creador)
  VALUES ('Comunidad', 'Acceso a la comunidad', 10, demo_creador_id)
  RETURNING id_plan INTO id_plan_comunidad;

  INSERT INTO plan_suscripcion (nombre, descripcion, precio, id_creador)
  VALUES ('Fellow', 'Acceso cercano al creador', 25, demo_creador_id)
  RETURNING id_plan INTO id_plan_fellow;

  -- Suscripción ACTIVA del fan demo a ambos planes (fecha_fin NULL = no expira)
  INSERT INTO suscripcion (id_usuario, id_creador, id_plan, fecha_inicio, fecha_fin)
  VALUES (demo_fan_id, demo_creador_id, id_plan_comunidad, now(), NULL);

  INSERT INTO suscripcion (id_usuario, id_creador, id_plan, fecha_inicio, fecha_fin)
  VALUES (demo_fan_id, demo_creador_id, id_plan_fellow, now(), NULL);

  -- Chat de Comunidad (grupal) con el fan ya adentro + un mensaje de ejemplo
  INSERT INTO chat (tipo, nombre, creado_por, id_creador, id_plan)
  VALUES ('group', 'Comunidad', demo_creador_id, demo_creador_id, id_plan_comunidad)
  RETURNING id_chat INTO id_chat_comunidad;

  INSERT INTO participante_chat (id_chat, id_usuario) VALUES (id_chat_comunidad, demo_fan_id);

  INSERT INTO mensaje (id_chat, id_remitente, contenido)
  VALUES (id_chat_comunidad, demo_creador_id, '¡Bienvenido a la comunidad! Este es un mensaje de ejemplo.');

  -- Chat Fellow (DM 1:1) con un intercambio de mensajes de ejemplo
  INSERT INTO chat (tipo, creado_por)
  VALUES ('dm', demo_fan_id)
  RETURNING id_chat INTO id_chat_fellow;

  INSERT INTO participante_chat (id_chat, id_usuario) VALUES (id_chat_fellow, demo_fan_id);
  INSERT INTO participante_chat (id_chat, id_usuario) VALUES (id_chat_fellow, demo_creador_id);

  INSERT INTO mensaje (id_chat, id_remitente, contenido)
  VALUES (id_chat_fellow, demo_creador_id, 'Hola, gracias por suscribirte a Fellow.');
  INSERT INTO mensaje (id_chat, id_remitente, contenido)
  VALUES (id_chat_fellow, demo_fan_id, '¡Hola! Probando la app.');
END $$;

-- ============================================================
-- PASO 4 — En App Store Connect → App Review Information:
--   Sign-in required: sí
--   Username: demo.fan@sincbo.app
--   Password: (la que le pusiste al registrarla)
--   Notes: "La cuenta ya tiene suscripciones activas (Comunidad y Fellow)
--   a la cuenta demo.creador@sincbo.app, con chats y mensajes de ejemplo
--   precargados. No requiere pago para ver el contenido."
-- ============================================================
