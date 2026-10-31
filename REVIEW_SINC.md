# Review técnico — Sinc (Flutter + Supabase)

Revisión hecha sobre el código en `lib/`, `pubspec.yaml`, historial de git, el esquema completo de tablas, las políticas RLS y el código SQL de tus funciones RPC y Edge Functions (VPay) que compartiste.

Voy a empezar por el backend porque es, con diferencia, lo más urgente: hay varias formas de saltarse los pagos y de leer datos de otros usuarios ahora mismo, y ninguna requiere hackear nada sofisticado, solo llamar directo a la API de Supabase con la anon key que ya viene embebida en el APK/IPA (eso es normal y esperado en Supabase — la seguridad real tiene que vivir en RLS y en las funciones, no en el cliente).

## 0. Backend: RLS está apagado en casi todas las tablas

De 17 tablas en `public`, solo 3 tienen Row Level Security habilitado: `admin_user`, `mensaje` y `vpay_tokens`. Todas las demás —`usuario`, `creador`, `suscripcion`, `transaccion`, `publicacion`, `multimedia`, `comentario`, `me_gusta`, `chat`, `participante_chat`, `plan_suscripcion`, `metodo_pago`, `categoria`— tienen RLS **desactivado**.

En Supabase, cuando RLS está desactivado en una tabla, esa tabla queda expuesta tal cual a cualquiera que tenga la anon key (que está en tu `.env` y viaja dentro de la app — no es un secreto, ese es justamente el punto de RLS). En la práctica, hoy cualquier persona con esa key y una llamada REST directa (sin pasar por tu app Flutter) puede:

Leer la tabla `transaccion` completa: montos, quién le pagó a qué creador, cuándo — de todos los usuarios, no solo el suyo. Leer/editar la tabla `usuario` completa: cualquiera podría hacer `update` sobre el perfil de cualquier otro usuario (tu propio código en `auth.datasource.dart` ya hace `client.from('usuario').update(...)`, así que la tabla necesita aceptar updates — el problema es que sin RLS acepta el update de cualquiera, no solo del dueño de la fila). Leer/editar `creador` y `plan_suscripcion`, incluyendo `precio_suscripcion` y `precio` — en teoría cualquiera podría cambiar el precio de un plan. Leer todo el contenido de `publicacion` sin importar `es_publico`, es decir, el paywall de contenido no está protegido a nivel de base de datos, solo por lo que tu UI decide mostrar.

Lo más importante: en la tabla `suscripcion` sí existen dos políticas bien escritas (`Leer suscripciones propias` con `auth.uid() = id_usuario`, y una de insert equivalente), pero como RLS está **desactivado en esa tabla**, esas políticas no se están aplicando en absoluto ahora mismo. Es decir, ya escribiste la regla correcta, solo falta un `ALTER TABLE suscripcion ENABLE ROW LEVEL SECURITY;` para que empiece a funcionar.

Acción inmediata: activar RLS en las 14 tablas que lo tienen apagado, y para cada una definir al menos una política de SELECT (y de INSERT/UPDATE/DELETE donde aplique) equivalente a lo que ya hiciste bien en `suscripcion`. Esto no se puede posponer para "después del refactor" — es el tipo de cosa que se explota en producción sin que te enteres.

## 1. La política "allow all insert" anula tu propia protección en `mensaje`

`mensaje` es de las 3 tablas con RLS activo, y tiene 3 políticas: una de SELECT bien hecha (`select_mensajes_si_es_participante_o_creador`, verifica que seas participante o el creador del chat) y dos de INSERT: `insert_mensaje_dm_o_solo_creador_en_group` (correcta, valida participante/creador según tipo de chat) y **`allow all insert`**, que tiene `with_check = true` sin ninguna condición.

En Postgres, cuando hay varias políticas PERMISSIVE para el mismo comando, se combinan con OR: basta con que una las apruebe. Como `allow all insert` siempre aprueba, la política cuidadosa que escribiste al lado queda completamente anulada. Cualquier usuario autenticado puede insertar un mensaje en cualquier chat, sea participante o no.

Y hay un segundo problema en la función `enviar_mensaje` (la que se usa para mensajes de solo texto): recibe `id_remitente_param` como parámetro desde el cliente y lo inserta tal cual, sin comparar contra `auth.uid()`. Aunque arregles la política de arriba, cualquiera podría seguir enviando un mensaje que aparente venir de otra persona (el creador, otro suscriptor) con solo pasar su UUID. Compara esto con `enviar_mensaje_con_imagenes`, que sí valida todo correctamente (`auth.uid()`, pertenencia al chat, quién puede mandar imágenes) — literalmente tienes el patrón correcto escrito al lado, solo falta aplicarlo a la función de texto plano.

Acción: borrar la política `allow all insert` (probablemente quedó de una prueba) y reescribir `enviar_mensaje` para usar `auth.uid()` en vez de recibir el remitente como parámetro, igual que ya hace la versión con imágenes.

## 2. `create_transaction` no valida el monto: se puede pagar cualquier suscripción por lo que uno quiera

```sql
create_transaction(p_id_creador uuid, p_id_plan uuid, p_monto numeric)
```

Esta función es `SECURITY DEFINER` y hace `INSERT INTO transaccion (..., monto, ...) VALUES (..., p_monto, ...)` con el monto que le mande el cliente, sin compararlo nunca contra `plan_suscripcion.precio` para ese `p_id_plan`. El precio real de la suscripción vive en `plan_suscripcion`, pero esta función confía ciegamente en lo que Flutter le mande.

Como cualquier usuario autenticado puede invocar RPCs directamente (no hace falta pasar por tu app), esto significa que alguien puede llamar `create_transaction` con el `id_plan` real de un creador pero un `p_monto` de, por ejemplo, 1 boliviano. Esa transacción sigue el flujo normal: `vpay-generate-qr` lee `tx.monto` (ya manipulado) y genera un QR real por ese monto bajo, la persona lo paga de verdad, el callback confirma el pago real ante VPay (esa parte sí está bien hecha, ver punto 4) y termina creando/extendiendo una suscripción completa de un mes por prácticamente nada. El bug no está en la validación del pago con VPay — está en que nadie valida que el monto cobrado corresponda al precio real del plan antes de generar el QR.

Acción: dentro de `create_transaction`, buscar el precio real con `SELECT precio FROM plan_suscripcion WHERE id_plan = p_id_plan AND id_creador = p_id_creador` y usar ese valor en vez de `p_monto` (o como mínimo, validar que coincidan y lanzar excepción si no). De paso, hoy tampoco valida que el plan pertenezca al creador indicado, cosa que `get_or_create_chat_por_plan` sí hace — sería bueno agregar esa misma validación aquí.

## 3. Se puede entrar a un chat de comunidad (de pago) sin haber pagado

`get_or_create_chat_por_plan(p_id_usuario, p_id_creador, p_id_plan)` valida que el plan pertenezca al creador, pero nunca valida que `p_id_usuario` tenga una suscripción activa a ese plan (no llama a `esta_suscrito` ni revisa la tabla `suscripcion`). Cualquiera que conozca el `id_plan` de un creador (que además es público: lo devuelve `obtener_creadores()` en el campo `planes`) puede llamar esta función con su propio `auth.uid()` y quedar agregado como `participante_chat` del chat grupal de "Comunidad" de ese creador, sin haber pagado nunca. Como tampoco valida `p_id_usuario = auth.uid()`, ni siquiera necesita ser el propio usuario quien haga la llamada.

Acción: agregar al inicio de la función una verificación tipo `IF NOT EXISTS (SELECT 1 FROM suscripcion WHERE id_usuario = p_id_usuario AND id_plan = p_id_plan AND fecha_fin > now()) THEN RAISE EXCEPTION 'No tienes una suscripción activa a este plan'; END IF;`, y forzar `p_id_usuario := auth.uid()` en vez de confiar en el parámetro.

## 4. Funciones de analytics filtran datos de cualquier creador, no solo el tuyo

`get_ganancias_creador_mes_v1(p_id_creador, ...)` y `get_top_pagos_creador_mes_v1(p_id_creador, ...)` son `SECURITY DEFINER` (o sea, corren con privilegios elevados sin que RLS las frene) y reciben `p_id_creador` como parámetro sin comprobar en ningún momento que `p_id_creador = auth.uid()`. Cualquier usuario autenticado puede llamar `get_ganancias_creador_mes_v1('<id de cualquier creador>', 2026, 7)` y ver las ganancias brutas, el fee y el balance mensual de ese creador, y con `get_top_pagos_creador_mes_v1` incluso ver los nombres de sus suscriptores que más pagaron y cuánto. `get_creadores_por_tipo(p_user_id, p_tipo)` tiene el mismo problema pero al revés: pasa cualquier `p_user_id` y ves a qué creadores y planes está suscrito ese usuario.

En contraste, `get_mis_suscriptores_por_tipo` sí está bien hecha: usa `auth.uid()` internamente y verifica que quien llama sea efectivamente un creador (`EXISTS (SELECT 1 FROM creador WHERE id_creador = auth.uid())`). Ese es el patrón a copiar en las otras tres.

Acción: en las tres funciones, reemplazar el parámetro recibido por `auth.uid()` (o agregar `IF p_id_creador <> auth.uid() THEN RAISE EXCEPTION ... END IF;` al inicio) para que solo puedas ver tus propios números.

## 5. Lo que sí está bien hecho en las Edge Functions de VPay

Vale la pena decirlo porque no todo es malo: `callback-vpay` no confía en el estado de pago que le manda el body del request (`estadoQr`/similar), sino que hace su propia llamada server-to-server a `vpay.com.bo/.../statusQr` con su propio token para confirmar el estado real antes de tocar la base — eso es exactamente lo correcto para un webhook de pagos, y evita que alguien falsifique un "PAG" solo llamando al endpoint del callback. También tiene control de idempotencia (`if (tx.estado === "PAG") return`), así que reintentos del proveedor no duplican la extensión de la suscripción.

Dos cosas menores ahí: ni `callback-vpay` ni `vpay-generate-qr` verifican que quien invoca sea realmente VPay o el usuario dueño de la transacción (no hay validación de firma/secreto compartido en el callback, ni chequeo de que `auth.uid()` coincida con `tx.id_usuario` en `vpay-generate-qr`). El riesgo real es bajo porque los `id_qr`/`id_transaccion` son UUIDs no adivinables, pero es defensa en profundidad que falta.

`vpay-generate-token` parece código muerto: no lo llama nada en tu app Flutter, y guarda tokens de VPay en una tabla `vpay_tokens` sin usar ningún campo de expiración real (el `expires_in_hours: 24` solo va en la respuesta, no se guarda). Si no lo estás usando desde otro lado, se puede borrar.

## 6. Modelo de datos: precio duplicado y sin validar consistencia

El precio de una suscripción vive en tres lugares potencialmente distintos: `creador.precio_suscripcion`, `creador.precio_suscripcion_fellow` y `plan_suscripcion.precio`. No hay ningún constraint ni trigger que los mantenga sincronizados. Sumado al punto 2 (el monto tampoco se valida contra ninguno de estos al cobrar), esto es una fuente fácil de inconsistencias entre lo que se le muestra al usuario y lo que termina en `transaccion`. Yo consolidaría el precio en un solo lugar (`plan_suscripcion.precio`, que ya está bien modelado con `id_creador`) y quitaría las columnas de precio de `creador`.

También noté que `transaccion.estado` es un `text` libre sin `CHECK` (solo tiene default `'PEN'`) — dado que el código y las funciones asumen valores fijos (`PEN`, `PAG`, y presumiblemente `REV`/`ANU` que vi mencionados en el código Flutter), conviene un `CHECK (estado IN ('PEN','PAG','REV','ANU'))` para que no se cuele un valor inválido desde algún lado.

---

## 7. Bloqueador crítico en Flutter: ahora mismo la app no compila

El último commit ("new refactor app sinc") borró `lib/feature/auth/AuthGate.dart`, pero `lib/app.dart` sigue importando `feature/auth/auth_gate.dart` y usando el widget `AuthGate`. Ese archivo no existe en ningún lado del proyecto. Es literalmente el punto de entrada de la app (decide si mostrar login o home), así que en el estado actual del repo un `flutter run` falla en compilación. Esto hay que arreglarlo antes que cualquier otra cosa: recrear el widget (era muy simple, ~30 líneas, lo tengo en el historial de git si lo quieres recuperar tal cual) o apuntar el import al archivo correcto si se movió con otro nombre.

El mismo commit también borró `lib/data/datasources/paymente.datasource.dart` sin dejar un reemplazo real: `payment_datasource_provider.dart` y `payment_repository.dart` siguen importando `data/datasources/payment.datasource.dart`, archivo que tampoco existe. Todo el módulo de pagos vía `PaymentRepository`/`PaymentDataSource` está roto (ahora mismo nada de la UI lo usa, ver punto 9, pero sigue referenciado desde `providers.dart`).

## 8. Clean Architecture aplicada a medias

Tu `AGENTS.md` exige Clean Architecture y Riverpod estrictos, pero en la práctica hay dos patrones conviviendo. `AuthRepository` y `CreatorRepository` están bien hechos: interfaz abstracta en `domain/repositories`, implementación concreta en `data/repositories` que depende del datasource, e inyección vía provider. Es el patrón correcto y deberías replicarlo en todo lo demás.

`ChatRepository` y `PaymentRepository`, en cambio, son clases concretas que viven directamente en `domain/repositories` e importan `ChatDataSource`/`PaymentDataSource` de la capa de datos sin ninguna interfaz de por medio. Eso invierte la regla de dependencia que exige Clean Architecture y hace que esas dos piezas no se puedan testear con mocks sin arrastrar Supabase.

Además, cada feature en `lib/feature/*` tiene carpetas `data/` y `domain/` vacías (auth, chat, community, creator_profile, earnings, fellow, home, profile, subscription). El esqueleto de "Clean Architecture por feature" está creado pero nunca se usó: todo el código real vive centralizado en `lib/data` y `lib/domain`. Decide un solo enfoque y borra las carpetas vacías que no vas a usar.

También noté que `AGENTS.md` manda a "consultar /docs antes de generar código" (README, project-architecture.md, flutter-coding-standards.md, riverpod-state-management.md, ui-widget-guidelines.md, code-organization.md), pero esa carpeta `/docs` no existe en el repo. Vale la pena recrearla o quitar esa instrucción.

## 9. Pagos/QR: la misma funcionalidad implementada 3 veces en el cliente

`VPayService` (`lib/data/datasources/vpay_service.dart`) llama directamente por HTTP a `vpay.com.bo:7778` con credenciales de prueba hardcodeadas y no lo usa nadie — código muerto. Además usa el paquete `http`, que no está declarado como dependencia directa en `pubspec.yaml` (solo transitiva en `pubspec.lock`), lo cual es frágil.

`PaymentDataSource` + `PaymentRepository` está roto ahora mismo por el punto 7, y tampoco lo usa la UI.

Lo que de verdad se ejecuta está en `payment_confirmation.page.dart`: dos `FutureProvider` privados definidos dentro del propio archivo de UI que llaman directo a `client.functions.invoke('vpay-generate-qr'/'vpay-get-qr')`, saltándose datasource, repositorio y dominio por completo.

Recomendación: elige una sola implementación (la de Edge Functions, que es la vigente), muévela a `PaymentDataSource` → `PaymentRepository` → provider, y borra `VPayService` y el archivo `payment.datasource.dart`/`paymente.datasource.dart` huérfano. El widget además tiene hardcodeado `destinationAccountId = '3332CO'` y `callbackUrl = 'https://tuapp.com/api/callback'` como default — mejor moverlo a configuración de servidor (de hecho `vpay-generate-qr` ya define `destinationAccountId` y `callbackUrl` del lado servidor vía variables de entorno, así que el valor del cliente ni debería importar — otra razón para no calcular el QR en el cliente).

## 10. `supabase_datasource.dart`: datasource "legado" de 1267 líneas que sigue vivo

Es el archivo más grande del proyecto y el propio comentario en `providers.dart` dice `// TODO: migrar los usos de supabaseDataSourceProvider a datasources específicos`. Ya existen datasources específicos por feature, pero el legado sigue inyectado y usado en `subscription.page.dart`. Tiene lógica duplicada (`obtener_creadores`, `enviar_mensaje`, `get_or_create_chat_por_plan` están en ambos lados) y consultas a una tabla `creadores` (plural) que no existe — la tabla real es `creador` (singular), así que esas rutas de fallback están muertas o rotas.

Ahí mismo, la función que crea la transacción (`create_transaction`) prueba 4 combinaciones de parámetros hasta que alguna no tire error. Ya con el SQL real confirmado: la firma correcta es `create_transaction(p_id_creador uuid, p_id_plan uuid, p_monto numeric)` — es decir, el `attempt1` (con `p_id_creador`, `p_id_plan`, `p_monto`) es el único que puede funcionar; `attempt3` y `attempt4` (con `p_tipo` en vez de `p_id_plan`) van a fallar siempre porque esa función no tiene ningún parámetro `p_tipo`. Puedes borrar los 3 intentos que sobran y dejar una sola llamada limpia — y de paso corregir el bug de seguridad del punto 2 mientras estás ahí.

## 11. Páginas con demasiada lógica embebida

`login.page.dart` tiene 905 líneas, `creator_profile.page.dart` 481, `payment_confirmation.page.dart` 449, `profile.page.dart` 363. Varias definen sus propios providers privados inline en vez de moverlos a `core/providers` o a un controller dedicado. El feature `community` sí tiene el patrón completo correcto (controller + provider + state en archivos separados) — es el ejemplo a seguir para chat, subscription y profile.

## 12. Archivos muertos, configuración y detalles menores

`lib/data/local/local_session.dart` existe pero está vacío (0 bytes) — a juzgar por el commit "login save local" la persistencia de sesión local quedó a medias; no hay uso de `shared_preferences` pese a estar en el árbol de dependencias.

Hay una carpeta con un espacio en el nombre por typo: `lib/feature/chat/data/ models/chat_message_mapper.dart` (debería ser `models/`).

`upload-keystore.jks` (keystore de firma de release para Android) está en la raíz del proyecto. No está trackeado en git, lo cual es bueno, pero conviene sacarlo del directorio del proyecto o confirmar que `.gitignore` lo cubra explícitamente.

Testing: solo 2 archivos de test (`widget_test.dart` boilerplate y `search_bar_test.dart`). No hay tests de repositorios, datasources ni controllers — con la cantidad de lógica que vive en el datasource legado y en las páginas, cualquier refactor hoy es "a ciegas".

## Prioridad sugerida

1. **Activar RLS en las 14 tablas que lo tienen apagado** (punto 0) — es explotable ahora mismo, no requiere ningún refactor de Flutter, solo SQL.
2. **Arreglar `create_transaction` para validar el monto contra `plan_suscripcion.precio`** (punto 2) — es fraude de precio, dinero real.
3. **Borrar la política `allow all insert` de `mensaje` y arreglar `enviar_mensaje` para usar `auth.uid()`** (punto 1) — suplantación de identidad en chats.
4. **Agregar validación de suscripción activa en `get_or_create_chat_por_plan`** (punto 3) — acceso gratis a comunidades pagas.
5. Restringir `get_ganancias_creador_mes_v1`, `get_top_pagos_creador_mes_v1` y `get_creadores_por_tipo` a `auth.uid()` (punto 4).
6. Arreglar el build (`AuthGate` y `payment.datasource.dart` faltantes, punto 7) — sin esto la app no corre.
7. Unificar el flujo de pagos en una sola implementación (punto 9) y limpiar los 4 intentos de `create_transaction` en el cliente (punto 10).
8. Estandarizar Chat y Payment al mismo patrón interfaz/impl que ya usan Auth y Creator; decidir si las carpetas vacías por feature se usan o se eliminan (punto 8).
9. Sacar la lógica de providers privados embebidos en páginas hacia controllers, siguiendo el patrón de `community` (punto 11).
10. Sumar tests de repositorios/datasources antes de seguir refactorizando.

## Estado: qué ya quedó resuelto en este repo

Ya apliqué del lado de Flutter lo necesario para que el fix de backend no rompa nada:

- `fix_seguridad_supabase.sql` (en la raíz del proyecto) tiene listo todo el SQL de los puntos 0-4: activar RLS en las 14 tablas, borrar la política `allow all insert`, y recrear `create_transaction`, `enviar_mensaje`, `get_or_create_chat_por_plan`, `get_ganancias_creador_mes_v1`, `get_top_pagos_creador_mes_v1` y `get_creadores_por_tipo` con los fixes de seguridad. **Este SQL todavía no se ha corrido en tu proyecto de Supabase** — tienes que pegarlo tú en el SQL Editor.
- Actualicé todas las llamadas RPC en Flutter (`chat.datasource.dart`, `creator.datasource.dart`, `analytics.datasources.dart`, y también en el legado `supabase_datasource.dart` porque confirmé que `subscription.page.dart` y `GananciasPage` todavía lo usan) para que dejen de mandar los parámetros que las funciones ya no aceptan (`id_remitente_param`, `p_user_id`, `p_id_creador`).
- Recreé `lib/feature/auth/auth_gate.dart` (arregla el bloqueador del punto 7 — la app ya compila) y `lib/data/datasources/payment.datasource.dart` (arregla el `PaymentRepository`, que descubrí que es el que usa de verdad el botón "Suscribirse" en `creator_profile.page.dart` — estaba roto en producción, no solo en teoría). Ajusté `payment_repository.dart` y ese call site para que ya no manden el precio del lado del cliente (el monto ahora se calcula siempre en `create_transaction`, del lado servidor).

Lo único que falta de tu parte: correr `fix_seguridad_supabase.sql` en el SQL Editor de Supabase. Los puntos 8-12 (Clean Architecture pareja, unificar pagos, borrar `supabase_datasource.dart`, tests) siguen pendientes como refactor de fondo, sin apuro de seguridad.
