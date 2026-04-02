import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/creator_model.dart';
import '../models/message_model.dart';
import '../models/chat_con_creador_model.dart';
import '../models/creator_por_tipo_model.dart';
import '../models/ganancias_mes_model.dart';
import '../models/top_pago_mes_model.dart';
import '../models/usuario_por_tipo_model.dart';
import '../utils/safe_map.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

class SupabaseDataSource {
  final SupabaseClient client;

  SupabaseDataSource(this.client);

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) return null;

      final profile = await client
          .from('usuario')
          .select('id_usuario, email, nombre_usuario, es_creador')
          .eq('id_usuario', user.id)
          .maybeSingle(); // 👈 mejor que single()

      if (profile != null) {
        return UserModel.fromAuthAndProfile(user, profile);
      }

      // fallback si no existe en tabla
      return UserModel.fromUser(user);
    } catch (e) {
      debugPrint('signInWithEmail -> error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Cambia la contraseña del usuario actual
  /// Solo requiere la nueva contraseña ya que el usuario está autenticado
  Future<void> changePassword({required String newPassword}) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('No hay usuario autenticado');
      }

      debugPrint('changePassword -> Updating password for user: ${user.id}');

      // Actualizar a la nueva contraseña
      final response = await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw Exception('No se pudo actualizar la contraseña');
      }

      debugPrint('changePassword -> Password updated successfully');
    } catch (e) {
      debugPrint('changePassword -> error: $e');
      rethrow;
    }
  }

  /// Envía un email para resetear la contraseña
  Future<void> resetPasswordForEmail(String email) async {
    try {
      debugPrint('resetPasswordForEmail -> Sending reset email to: $email');

      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.sincbo.sincboflutter://login-callback',
      );

      debugPrint('resetPasswordForEmail -> Reset email sent successfully');
    } catch (e) {
      debugPrint('resetPasswordForEmail -> error: $e');
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;

      if (user == null) {
        debugPrint('getCurrentUser -> NO AUTH USER');
        return null;
      }

      debugPrint('getCurrentUser -> querying usuario for id=${user.id}');

      final profile = await client
          .from('usuario')
          .select('id_usuario, email, nombre_usuario, es_creador')
          .eq('id_usuario', user.id)
          .maybeSingle();

      debugPrint('getCurrentUser -> profile result: $profile');

      if (profile == null) {
        debugPrint('getCurrentUser -> NO PROFILE found for user ${user.id}');
        return null;
      }

      return UserModel.fromAuthAndProfile(user, profile);
    } catch (e, st) {
      debugPrint('getCurrentUser -> error: $e\n$st');
      return null;
    }
  }

  /// Inicia sesión con Google OAuth
  /// No crea automáticamente el usuario en la tabla, solo autentica
  Future<User?> signInWithGoogle() async {
    return _signInWithOAuthProvider(
      OAuthProvider.google,
      'signInWithGoogle',
    );
  }

  /// Inicia sesión con Facebook OAuth
  /// No crea automáticamente el usuario en la tabla, solo autentica
  Future<User?> signInWithFacebook() async {
    return _signInWithOAuthProvider(
      OAuthProvider.facebook,
      'signInWithFacebook',
    );
  }

  Future<User?> _signInWithOAuthProvider(
      OAuthProvider provider,
      String providerName,
      ) async {
    try {
      debugPrint('$providerName -> Starting OAuth flow');

      // ⚡ Suscribir ANTES de lanzar el OAuth para no perder el evento signedIn
      final completer = Completer<User?>();
      StreamSubscription? subscription;
      subscription = client.auth.onAuthStateChange.listen((data) {
        debugPrint('$providerName -> auth event: ${data.event}');
        if (data.event == AuthChangeEvent.signedIn &&
            data.session?.user != null &&
            !completer.isCompleted) {
          completer.complete(data.session!.user);
        }
      });

      final res = await client.auth.signInWithOAuth(
        provider,
        redirectTo: 'com.sincbo.sincboflutter://login-callback',
      );

      if (!res) {
        await subscription.cancel();
        debugPrint('$providerName -> OAuth flow not started');
        return null;
      }

      final user = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('$providerName -> Timeout, using currentUser');
          return client.auth.currentUser;
        },
      );

      await subscription.cancel();

      if (user == null) {
        debugPrint('$providerName -> No user after callback');
        return null;
      }

      debugPrint('$providerName -> User authenticated: ${user.id}');
      return user;
    } catch (e) {
      debugPrint('$providerName -> error: $e');
      rethrow;
    }
  }

  Future<List<CreatorModel>> obtenerCreadores() async {
    // Llama al procedimiento almacenado 'obtener_creadores'
    final res = await client.rpc('obtener_creadores');

    // Si tu RPC devuelve directamente una lista de mapas (lo normal en Supabase)
    if (res is List) {
      return res.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return CreatorModel.fromMap(map);
      }).toList();
    }

    // Si por algún motivo el resultado es nulo o inesperado
    return [];
  }

  /// Server-side search for creators using ilike on nombre_usuario and categoria.
  /// Returns a list of CreatorModel with optional limit and offset (range).
  Future<List<CreatorModel>> buscarCreadores(String query, {int limit = 50, int offset = 0}) async {
    try {
      // If the query is empty, return a first page from the 'creadores' table.
      if (query.trim().isEmpty) {
        final res = await client.from('creadores').select().limit(limit).range(offset, offset + limit - 1);
        List<dynamic> list;
        try {
          list = List<dynamic>.from(res);
        } catch (_) {
          list = <dynamic>[];
        }
        final result = list.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return CreatorModel.fromMap(map);
        }).toList();
        if (result.isEmpty) {
          final rpcRes = await client.rpc('obtener_creadores');
          if (rpcRes is List) {
            final rpcList = rpcRes.map((e) => normalizeKeys(mapFromDynamic(e))).toList();
            final mapped = rpcList.map((m) => CreatorModel.fromMap(m)).toList();
            return mapped;
          }
        }
        return result;
      }

      // Use ilike for case-insensitive partial match on nombre_usuario or categoria
      final pattern = '%$query%';
      final orClause = 'nombre_usuario.ilike.$pattern,categoria.ilike.$pattern';

      final res = await client.from('creadores').select().or(orClause).limit(limit).range(offset, offset + limit - 1);
      List<dynamic> list;
      try {
        list = List<dynamic>.from(res);
      } catch (_) {
        list = <dynamic>[];
      }
      if (list.isEmpty) {
        final rpcRes = await client.rpc('obtener_creadores');
        if (rpcRes is List) {
          final rpcList = rpcRes.map((e) => normalizeKeys(mapFromDynamic(e))).toList();
          // If query provided, filter client-side using robust getter
          final filtered = rpcList.where((m) {
            final nombre = getStringFromMap(m, ['nombre_usuario', 'nombreUsuario', 'nombre']).toLowerCase();
            final categoria = getStringFromMap(m, ['categoria', 'category']).toLowerCase();
            return nombre.contains(query.toLowerCase()) || categoria.contains(query.toLowerCase());
          }).skip(offset).take(limit).toList();
          final mapped = filtered.map((m) => CreatorModel.fromMap(m)).toList();
          return mapped;
        }
        return [];
      }
      final result = list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return CreatorModel.fromMap(map);
      }).toList();
      return result;
    } catch (e) {
      // On unexpected shapes or errors, return empty list and allow upper layers to handle/log if needed.
      return [];
    }
  }

  /// Checks if the current authenticated user is subscribed to the given creator
  /// by calling the Postgres RPC `esta_suscrito(p_id_usuario, p_id_creador)`.
  /// Returns `false` on error or when unauthenticated.
  Future<bool> estaSuscrito(String idCreador) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return false;
      }

      final rpcRes = await client.rpc('esta_suscrito', params: {
        'p_id_usuario': user.id,
        'p_id_creador': idCreador,
      });

      if (rpcRes == null) return false;

      // RPC can return a boolean directly, or a list with a single boolean, or a map.
      if (rpcRes is bool) return rpcRes;

      if (rpcRes is List && rpcRes.isNotEmpty) {
        final first = rpcRes.first;
        if (first is bool) return first;
        if (first is Map) {
          // try to extract a boolean value from the map
          final boolValues = first.values.whereType<bool>().toList();
          if (boolValues.isNotEmpty) return boolValues.first;
        }
      }

      if (rpcRes is Map) {
        final boolValues = rpcRes.values.whereType<bool>().toList();
        if (boolValues.isNotEmpty) return boolValues.first;
      }

      // Fallbacks: string or numeric representations
      if (rpcRes is String) {
        final s = rpcRes.toLowerCase();
        if (s == 'true' || s == 't' || s == '1') return true;
        return false;
      }

      if (rpcRes is num) return rpcRes == 1;

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Creates a chat and its participants by calling the Postgres RPC
  /// `crear_chat_y_participantes(id_usuario, id_creador)` and returns the
  /// created chat id as a String, or null on failure.
  Future<String?> crearChatYParticipantes(String idCreador, String idPlan, bool isCreator) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return null;
      }

      final rpcRes = await client.rpc('get_or_create_chat_por_plan', params: {
        'p_id_usuario': isCreator? idCreador : user.id,
        'p_id_creador': isCreator? user.id : idCreador,
        'p_id_plan': idPlan,
      });

      if (rpcRes == null) return null;

      // Typical case: RPC returns a scalar string id
      if (rpcRes is String) return rpcRes;

      // Sometimes Supabase returns a list with a single scalar or map
      if (rpcRes is List && rpcRes.isNotEmpty) {
        final first = rpcRes.first;
        if (first is String) return first;
        if (first is Map) {
          // Try to find a string value inside the map
          final stringValues = first.values.whereType<String>().toList();
          if (stringValues.isNotEmpty) return stringValues.first;
        }
        if (first is num) return first.toString();
      }

      if (rpcRes is Map) {
        final stringValues = rpcRes.values.whereType<String>().toList();
        if (stringValues.isNotEmpty) return stringValues.first;
        final numValues = rpcRes.values.whereType<num>().toList();
        if (numValues.isNotEmpty) return numValues.first.toString();
      }

      // Fallback: numeric id
      if (rpcRes is num) return rpcRes.toString();
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Busca o crea un chat de comunidad para el creador sin necesitar un plan.
  /// Primero intenta buscar un chat existente en la tabla chat donde id_creador coincide.
  /// Si no existe, crea uno nuevo.
  Future<String?> getOrCreateComunidadChatCreador(String idCreador) async {
    try {
      // Buscar chat existente del creador
      final existing = await client
          .from('chat')
          .select('id_chat')
          .eq('id_creador', idCreador)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        final id = existing['id_chat'];
        if (id is String && id.isNotEmpty) return id;
      }

      // Si no existe, crear uno nuevo
      final inserted = await client
          .from('chat')
          .insert({'id_creador': idCreador})
          .select('id_chat')
          .single();

      final id = inserted['id_chat'];
      if (id is String && id.isNotEmpty) return id;
      return null;
    } catch (e) {
      debugPrint('getOrCreateComunidadChatCreador -> error: $e');
      return null;
    }
  }

  /// Sends a message via the Postgres RPC `enviar_mensaje(id_chat_param, id_remitente_param, contenido_param)`.
  /// Returns true on success, false on failure (including unauthenticated user).
  Future<bool> enviarMensaje(String idChat, String contenido) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return false;
      }

      // Call the RPC. We don't expect a particular return value; success is indicated by no exception.
      await client.rpc('enviar_mensaje', params: {
        'id_chat_param': idChat,
        'id_remitente_param': user.id,
        'contenido_param': contenido,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Envía un mensaje con imágenes usando el RPC `enviar_mensaje_con_imagenes`.
  /// Devuelve el `id_mensaje` como String o null si falla.
  Future<String?> enviarMensajeConImagenes({
    required String chatId,
    required String text,
    required List<String> imageUrls,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return null;
      }

      final res = await client.rpc('enviar_mensaje_con_imagenes', params: {
        'p_id_chat': chatId,
        'p_contenido': text,
        'p_urls': imageUrls, // puede ser []
      });

      // Helper to extract id_mensaje across common shapes
      String? parseId(dynamic value) {
        if (value == null) return null;
        if (value is String && value.isNotEmpty) return value;
        if (value is num) return value.toString();
        if (value is List && value.isNotEmpty) return parseId(value.first);
        if (value is Map) {
          final candidates = [
            value['id_mensaje'],
            value['idMensaje'],
            value['message_id'],
            value['id'],
          ];
          for (final c in candidates) {
            final parsed = parseId(c);
            if (parsed != null) return parsed;
          }
          // Fallback: any first primitive value
          for (final v in value.values) {
            final parsed = parseId(v);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      return parseId(res);
    } catch (e) {
      debugPrint('enviarMensajeConImagenes -> error: $e');
      return null;
    }
  }

  /// Obtiene los chats a los que el usuario está suscrito llamando al RPC
  /// `obtener_chats_suscritos(id_usuario_input)` y devolviendo una lista de modelos.
  Future<List<ChatConCreadorModel>> obtenerChatsSuscritos() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return [];
      }

      final res = await client.rpc('obtener_chats_suscritos', params: {
        'id_usuario_input': user.id,
      });

      if (res == null) return [];

      if (res is List) {
        final list = res.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return ChatConCreadorModel.fromMap(map);
        }).toList();
        return list;
      }

      // If a single map returned
      if (res is Map) {
        final map = normalizeKeys(mapFromDynamic(res));
        return [ChatConCreadorModel.fromMap(map)];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch messages for a chat (ordered ascending by fecha_envio)
  Future<List<MessageModel>> obtenerMensajes(String idChat) async {
    try {
      final res = await client
          .from('mensaje')
          .select('*, mensaje_multimedia ( id_mensaje_multimedia, tipo, url, created_at )')
          .eq('id_chat', idChat)
          .order('fecha_envio', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);

      return list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));

        // 👇 aquí viene el array de adjuntos
        final mediaRaw = (map['mensaje_multimedia'] as List?) ?? const [];
        final media = mediaRaw
            .map((m) => MensajeMultimediaModel.fromMap(normalizeKeys(mapFromDynamic(m))))
            .toList();

        final base = MessageModel.fromMap(map);
        return MessageModel(
          idMensaje: base.idMensaje,
          idChat: base.idChat,
          idRemitente: base.idRemitente,
          contenido: base.contenido,
          fechaEnvio: base.fechaEnvio,
          multimedia: media,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }


  /// Insert a message into `mensaje` table returning the created row as MessageModel
  Future<MessageModel?> insertarMensaje(String idChat, String contenido) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return null;
      }

      // Insert and return the inserted row(s)
      final res = await client.from('mensaje').insert({
        'id_chat': idChat,
        'id_remitente': user.id,
        'contenido': contenido,
      }).select();

      // Supabase typically returns a list with the inserted row
      final List<dynamic> rows = res as List<dynamic>;
      if (rows.isNotEmpty) {
        final map = normalizeKeys(mapFromDynamic(rows.first));
        return MessageModel.fromMap(map);
      }

      return null;
    } catch (e) {
      // Fallback: in case the SDK returns a Map instead of List in some versions
      try {
        final map = normalizeKeys(mapFromDynamic(e));
        return MessageModel.fromMap(map);
      } catch (_) {
        return null;
      }
    }
  }

  Future<dynamic> generateQr({
    required double amount,
    required String gloss,
    String? additionalData,
    required String destinationAccountId,
    String? callbackUrl,
    String? transactionIdentifier,
  }) async {
    // If destinationAccountId looks like an internal UUID, the VPay API might expect a different account code.
    var destForVpay = destinationAccountId;
    final uuidLike = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-');
    if (uuidLike.hasMatch(destinationAccountId)) {
      debugPrint('generateQr -> destinationAccountId looks like a UUID ($destinationAccountId). Using fallback VPay account id "3332CO" for the request.');
      destForVpay = '3332CO';
    }

    // Build payload according to VPay documentation
    final expirationDate = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first; // yyyy-MM-dd
    final generatedTxId = DateTime.now().millisecondsSinceEpoch.toString();
    final txId = (transactionIdentifier != null && transactionIdentifier.isNotEmpty) ? transactionIdentifier : generatedTxId;

    final header = [
      {'attribute': 'currency', 'value': 'BOB'},
      {'attribute': 'gloss', 'value': gloss},
      {'attribute': 'amount', 'value': amount.toString()},
      {'attribute': 'expirationDate', 'value': expirationDate},
      {'attribute': 'additionalData', 'value': additionalData ?? gloss},
      {'attribute': 'destinationAccountId', 'value': destForVpay},
      {'attribute': 'transactionIdentifier', 'value': txId},
      // Use the documented example user; adjust if your integrator requires a different user
      {'attribute': 'user', 'value': 'testVpay'},
      {'attribute': 'company', 'value': '303'},
      {'attribute': 'originCollection', 'value': 'PWEB/APPM'},
      if (callbackUrl != null) {'attribute': 'callback', 'value': callbackUrl},
    ];

    // Detail items: include at least one item as required by the spec
    final detail = [
      {
        'items': [
          {'attribute': 'YGN-RUTA1', 'value': '2'},
        ]
      }
    ];

    final payload = {
      'operation': 'VTO041',
      'header': header,
      'detail': detail,
    };

    try {
      // Debug: show JSON-encoded payload to ensure formatting is correct
      debugPrint('generateQr -> calling vpay-generate-qr with payload (Map): $payload');
      dynamic response;
      try {
        response = await client.functions.invoke('vpay-generate-qr', body: payload);
      } catch (e) {
        debugPrint('generateQr -> first invoke error: $e');
        final errStr = e.toString();
        // If server reports missing fields, retry sending JSON string with explicit header
        if (errStr.toLowerCase().contains('campos requeridos') || errStr.toLowerCase().contains('falt') || errStr.toLowerCase().contains('required') || errStr.toLowerCase().contains('400')) {
          try {
            debugPrint('generateQr -> retrying invoke with JSON-encoded body');
            response = await client.functions.invoke('vpay-generate-qr', body: jsonEncode(payload), headers: {'Content-Type': 'application/json'});
          } catch (e2) {
            debugPrint('generateQr -> second invoke error: $e2');
            // Try a final attempt switching to operation VTO041 which some environments expect
            try {
              debugPrint('generateQr -> retrying with operation VTO041 as fallback');
              final payloadVTO041 = Map<String, dynamic>.from(payload);
              payloadVTO041['operation'] = 'VTO041';
              response = await client.functions.invoke('vpay-generate-qr', body: jsonEncode(payloadVTO041), headers: {'Content-Type': 'application/json'});
            } catch (e3) {
              debugPrint('generateQr -> third invoke error (VTO041): $e3');
              return {'ok': false, 'error': e3.toString(), 'payload': payload, 'destUsed': destForVpay};
            }
          }
        } else {
          return {'ok': false, 'error': errStr, 'payload': payload, 'destUsed': destForVpay};
        }
      }

       // Extract response data if available
       dynamic data;
       try {
         data = response.data;
       } catch (_) {
         data = response;
       }

      debugPrint('generateQr -> raw response data: $data');

      // If response indicates missing fields despite no thrown exception, attempt fallback op
      if (data is Map) {
        final low = data.toString().toLowerCase();
        if (low.contains('campos requeridos') || low.contains('falt') || low.contains('400') || low.contains('required')) {
          debugPrint('generateQr -> response contains missing-fields indication, retrying with VTO041');
          try {
            final payloadVTO041 = Map<String, dynamic>.from(payload);
            payloadVTO041['operation'] = 'VTO041';
            final retryResp = await client.functions.invoke('vpay-generate-qr', body: jsonEncode(payloadVTO041), headers: {'Content-Type': 'application/json'});
            try {
              final retryData = retryResp.data ?? retryResp;
              debugPrint('generateQr -> retry with VTO041 returned: $retryData');
              data = retryData;
            } catch (_) {}
          } catch (e) {
            debugPrint('generateQr -> retry with VTO041 failed: $e');
            // continue to parsing original data (which likely is an error map)
          }
        }
      }

      // Parse according to documentation: responseList -> response[] with code 'QR' and identificator base64
      if (data is Map && data.containsKey('responseList')) {
        try {
          final rl = data['responseList'];
          if (rl is List) {
            String? qrIdent;
            String? idIdent;
             for (final entry in rl) {
               if (entry is Map && entry.containsKey('response')) {
                 final responses = entry['response'];
                 if (responses is List) {
                   for (final r in responses) {
                     if (r is Map) {
                      final code = (r['code']?.toString() ?? '').toUpperCase();
                      final identificator = r['identificator'];
                      if (identificator is String) {
                        if (code == 'QR') {
                          qrIdent = identificator;
                        } else if (code == 'IDQR' || code == 'ID_QR' || code == 'IDQR') {
                          idIdent = identificator;
                        } else {
                          // Some providers may use other codes; try to heuristically detect base64 vs id
                          final candidate = identificator.trim();
                          if (candidate.length > 100) {
                            // likely the base64 image
                            qrIdent = candidate;
                          } else if (RegExp(r'^\d+\x00?\x00?\x00?\x00?\x00?\x00?\x00?\x00?\x00?\x00?').hasMatch(candidate) || RegExp(r'^\d{3,}$').hasMatch(candidate)) {
                            idIdent = candidate;
                          }
                        }
                      }
                     }
                   }
                 }
               }
             }

            // Prefer returning the QR image if found; otherwise return id if present
            if (qrIdent != null && qrIdent.isNotEmpty) {
              final dataUri = 'data:image/png;base64,$qrIdent';
              debugPrint('generateQr -> extracted QR data URI (post-collect)');
              return dataUri;
            }
            if (idIdent != null && idIdent.isNotEmpty) {
              return idIdent;
            }
           }
         } catch (e) {
           debugPrint('generateQr -> parsing responseList failed: $e');
         }
       }

      // If we couldn't extract the QR image, return the raw data for inspection
      return data;
    } catch (e) {
      debugPrint('generateQr -> error calling vpay-generate-qr: $e');
      return {'ok': false, 'error': e.toString(), 'payload': payload, 'destUsed': destForVpay};
    }
  }

  // Fetch QR by identifier using an edge function or equivalent server-side helper.
  // Returns a data-uri string (data:image/png;base64,...) when possible, otherwise returns raw response.
  Future<dynamic> getQrById(String id) async {
    final payload = {'id': id};
    try {
      debugPrint('getQrById -> invoking vpay-get-qr with id=$id');
      dynamic response;
      try {
        response = await client.functions.invoke('vpay-get-qr', body: payload);
      } catch (e) {
        debugPrint('getQrById -> first invoke error: $e');
        try {
          response = await client.functions.invoke('vpay-get-qr', body: jsonEncode(payload), headers: {'Content-Type': 'application/json'});
        } catch (e2) {
          debugPrint('getQrById -> second invoke error: $e2');
          return {'ok': false, 'error': e2.toString(), 'id': id};
        }
      }

      dynamic data;
      try {
        data = response.data;
      } catch (_) {
        data = response;
      }

      debugPrint('getQrById -> raw response data: $data');

      // Try to extract QR similar to generateQr parsing
      if (data is Map && data.containsKey('responseList')) {
        try {
          final rl = data['responseList'];
          if (rl is List) {
            String? qrIdent;
            String? idIdent;
            for (final entry in rl) {
              if (entry is Map && entry.containsKey('response')) {
                final responses = entry['response'];
                if (responses is List) {
                  for (final r in responses) {
                    if (r is Map) {
                      final code = (r['code']?.toString() ?? '').toUpperCase();
                      final identificator = r['identificator'];
                      if (identificator is String) {
                        final candidate = identificator.trim();
                        if (code == 'QR' || candidate.length > 100) {
                          qrIdent = candidate;
                        } else if (RegExp(r'^\d{3,}\x00?').hasMatch(candidate)) {
                          idIdent = candidate;
                        }
                      }
                    }
                  }
                }
              }
            }

            if (qrIdent != null && qrIdent.isNotEmpty) {
              final dataUri = 'data:image/png;base64,$qrIdent';
              debugPrint('getQrById -> extracted QR data URI');
              return dataUri;
            }
            if (idIdent != null && idIdent.isNotEmpty) return idIdent;
          }
        } catch (e) {
          debugPrint('getQrById -> parsing failed: $e');
        }
      }

      return data;
    } catch (e) {
      debugPrint('getQrById -> error: $e');
      return {'ok': false, 'error': e.toString(), 'id': id};
    }
  }

  /// Obtener creadores por tipo de plan (e.g., "Comunidad", "Fellow")
  /// Intenta primero con la tabla `creadores_por_tipo` y si no existe o falla,
  /// usa el RPC `obtener_creadores_por_tipo(p_tipo)`.
  Future<List<UsuarioPorTipoModel>> obtenerUsuarioPorTipo(String tipoPlan, {int limit = 50, int offset = 0}) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return [];
      }

      // Normalize tipoPlan to expected format if needed (e.g., lowercase)
      final tipo = tipoPlan.trim();

      final rpcRes = await client.rpc('get_mis_suscriptores_por_tipo', params: {
        'p_tipo': tipo,
      });
      // final rpcRes = await client.rpc('get_creadores_por_tipo', params: {
      //   'p_tipo': tipo,
      //   'p_user_id': user.id,
      // });

      if (rpcRes == null) return [];

      if (rpcRes is List) {
        return rpcRes.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return UsuarioPorTipoModel.fromMap(map);
        }).toList();
      }

      if (rpcRes is Map) {
        final map = normalizeKeys(mapFromDynamic(rpcRes));
        return [UsuarioPorTipoModel.fromMap(map)];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Obtener creadores por tipo de plan (e.g., "Comunidad", "Fellow")
  /// Intenta primero con la tabla `creadores_por_tipo` y si no existe o falla,
  /// usa el RPC `obtener_creadores_por_tipo(p_tipo)`.
  Future<List<CreatorPorTipoModel>> obtenerCreadoresPorTipo(String tipoPlan, {int limit = 50, int offset = 0}) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return [];
      }

      // Normalize tipoPlan to expected format if needed (e.g., lowercase)
      final tipo = tipoPlan.trim();

      // final rpcRes = await client.rpc('get_mis_suscriptores_por_tipo', params: {
      //   'p_tipo': tipo,
      // });
      final rpcRes = await client.rpc('get_creadores_por_tipo', params: {
        'p_tipo': tipo,
        'p_user_id': user.id,
      });

      if (rpcRes == null) return [];

      if (rpcRes is List) {
        return rpcRes.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return CreatorPorTipoModel.fromMap(map);
        }).toList();
      }

      if (rpcRes is Map) {
        final map = normalizeKeys(mapFromDynamic(rpcRes));
        return [CreatorPorTipoModel.fromMap(map)];
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Crea una transacción de suscripción/compra llamando al RPC `create_transaction`.
  /// Devuelve el `id_transaccion` como String o null si falla.
  Future<String?> createTransaction({
    required String creatorId,
    required String planId,
    required double price,
  }) async {
    // Helper to parse id_transaccion from various shapes
    String? _parseId(dynamic res) {
      if (res == null) return null;
      if (res is String && res.isNotEmpty) return res;
      if (res is num) return res.toString();
      if (res is List && res.isNotEmpty) return _parseId(res.first);
      if (res is Map) {
        final candidates = [
          res['id_transaccion'],
          res['idTransaccion'],
          res['transaction_id'],
          res['transactionId'],
        ];
        for (final c in candidates) {
          final parsed = _parseId(c);
          if (parsed != null) return parsed;
        }
        // Fallback: any string/num value
        for (final v in res.values) {
          final parsed = _parseId(v);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    try {
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('createTransaction -> no authenticated user');
        return null;
      }

      // Normalize possible plan type label
      final lowerPlan = planId.toLowerCase();
      final planTipo = lowerPlan.contains('fellow')
          ? 'Fellow'
          : (lowerPlan.contains('comunidad') ? 'Comunidad' : planId);

      // Attempt 1: as initially designed (with p_id_usuario)
      final attempt1 = {
        'p_id_creador': creatorId,
        'p_id_plan': planId,
        'p_monto': price,
        // 'p_id_usuario': user.id,
      };
      try {
        debugPrint('createTransaction -> attempt1 params=$attempt1');
        final res = await client.rpc('create_transaction', params: attempt1);
        final id = _parseId(res);
        if (id != null) return id;
      } catch (e) {
        debugPrint('createTransaction -> attempt1 error: $e');
      }

      // Attempt 2: without p_id_usuario (if RPC doesn't accept it)
      final attempt2 = {
        'p_id_creador': creatorId,
        'p_id_plan': planId,
        'p_monto': price,
      };
      try {
        debugPrint('createTransaction -> attempt2 params=$attempt2');
        final res = await client.rpc('create_transaction', params: attempt2);
        final id = _parseId(res);
        if (id != null) return id;
      } catch (e) {
        debugPrint('createTransaction -> attempt2 error: $e');
      }

      // Attempt 3: using p_tipo when backend expects a plan type instead of id
      final attempt3 = {
        'p_id_creador': creatorId,
        'p_tipo': planTipo, // e.g., 'Comunidad' or 'Fellow'
        'p_monto': price,
        // 'p_id_usuario': user.id,
      };
      try {
        debugPrint('createTransaction -> attempt3 params=$attempt3');
        final res = await client.rpc('create_transaction', params: attempt3);
        final id = _parseId(res);
        if (id != null) return id;
      } catch (e) {
        debugPrint('createTransaction -> attempt3 error: $e');
      }

      // Attempt 4: p_tipo without p_id_usuario
      final attempt4 = {
        'p_id_creador': creatorId,
        'p_tipo': planTipo,
        'p_monto': price,
      };
      try {
        debugPrint('createTransaction -> attempt4 params=$attempt4');
        final res = await client.rpc('create_transaction', params: attempt4);
        final id = _parseId(res);
        if (id != null) return id;
      } catch (e) {
        debugPrint('createTransaction -> attempt4 error: $e');
      }

      // If nothing worked, return null
      debugPrint('createTransaction -> all attempts failed');
      return null;
    } catch (e) {
      debugPrint('createTransaction -> unexpected error: $e');
      return null;
    }
  }

  /// Registra un usuario en Supabase Auth y luego inserta en la tabla `Usuario`.
  /// Nota: No guardes contraseñas en texto plano en producción.
  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String nombreUsuario,
    bool esCreador = false,
  }) async {
    try {
      // 1) Registro en Supabase Auth con metadatos
      final signUpRes = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre_usuario': nombreUsuario,
          'es_creador': esCreador,
        },
      );

      final user = signUpRes.user;
      if (user == null) {
        return null; // Sign-up could be pending email confirmation depending on project settings
      }

      // 2) Inserción en la tabla Usuario (ajusta el nombre/campos a tu esquema)
      try {
        await client.from('usuario').insert({
          'id_usuario': user.id,
          'nombre_usuario': nombreUsuario,
          'email': email,
          // 'contraseña': password, // ⚠️ Evitar in producción
          'es_creador': esCreador,
        });
      } catch (e) {
        // Si la fila ya existe o hay RLS, ignora o maneja según sea necesario
        debugPrint('signUpWithEmail -> insert Usuario error: $e');
      }

      return UserModel.fromUser(user);
    } catch (e) {
      debugPrint('signUpWithEmail -> error: $e');
      rethrow; // permite que la capa superior muestre el error
    }
  }

  /// Obtiene las ganancias del creador por mes desde el RPC `get_ganancias_creador_mes_v1`.
  /// Devuelve una lista de mapas con la forma:
  /// [{
  ///   anio, mes, total_bruto, fee, balance,
  ///   comunidad_monto, comunidad_suscriptores,
  ///   fellow_monto, tips_monto, contenido_solicitado_monto
  /// }]
  Future<List<Map<String, dynamic>>> obtenerGananciasCreadorMes({
    required String creadorId,
    required int year,
    required int month,
  }) async {
    try {
      final res = await client.rpc('get_ganancias_creador_mes_v1', params: {
        'p_id_creador': creadorId,
        'p_year': year,
        'p_month': month,
      });

      if (res == null) return [];

      List<Map<String, dynamic>> toList(dynamic value) {
        if (value is List) {
          return value.map((e) => normalizeKeys(mapFromDynamic(e))).toList();
        }
        if (value is Map) {
          return [normalizeKeys(mapFromDynamic(value))];
        }
        return [];
      }

      final list = toList(res);

      // Ensure expected keys exist with defaults
      return list.map((m) {
        return {
          'anio': m['anio'] ?? m['year'] ?? year,
          'mes': m['mes'] ?? m['month'] ?? month,
          'total_bruto': (m['total_bruto'] ?? m['subtotal'] ?? 0).toDouble(),
          'fee': (m['fee'] ?? m['founders_fee'] ?? 0).toDouble(),
          'balance': (m['balance'] ?? (m['total_bruto'] ?? 0) - (m['fee'] ?? 0)).toDouble(),
          'comunidad_monto': (m['comunidad_monto'] ?? 0).toDouble(),
          'comunidad_suscriptores': (m['comunidad_suscriptores'] ?? 0) is num ? (m['comunidad_suscriptores'] as num).toInt() : int.tryParse('${m['comunidad_suscriptores'] ?? 0}') ?? 0,
          'fellow_monto': (m['fellow_monto'] ?? 0).toDouble(),
          'tips_monto': (m['tips_monto'] ?? 0).toDouble(),
          'contenido_solicitado_monto': (m['contenido_solicitado_monto'] ?? 0).toDouble(),
        };
      }).toList();
    } catch (e) {
      debugPrint('obtenerGananciasCreadorMes -> error: $e');
      return [];
    }
  }

  /// Obtiene las ganancias del creador por mes desde el RPC `get_ganancias_creador_mes_v1`.
  /// Devuelve una lista de objetos `GananciasMesModel`.
  Future<List<GananciasMesModel>> obtenerGananciasCreadorMesModel({
    required String creadorId,
    required int year,
    required int month,
  }) async {
    try {
      final res = await client.rpc('get_ganancias_creador_mes_v1', params: {
        'p_id_creador': creadorId,
        'p_year': year,
        'p_month': month,
      });

      List<dynamic> list;
      if (res is List) {
        list = res;
      } else if (res is Map) {
        list = [res];
      } else {
        return [];
      }

      return list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return GananciasMesModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('obtenerGananciasCreadorMesModel -> error: $e');
      return [];
    }
  }

  /// Obtiene los pagos del creador por mes desde el RPC `get_top_pagos_creador_mes_v1`.
  /// Devuelve una lista de objetos `TopPagoMesModel`.
  Future<List<TopPagoMesModel>> obtenerTopPagosCreadorMes({
    required String creadorId,
    required int year,
    required int month,
    int limit = 10,
  }) async {
    try {
      final res = await client.rpc('get_top_pagos_creador_mes_v1', params: {
        'p_id_creador': creadorId,
        'p_year': year,
        'p_month': month,
        'p_limit': limit,
      });

      List<dynamic> list;
      if (res is List) {
        list = res;
      } else if (res is Map) {
        list = [res];
      } else {
        return [];
      }

      return list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return TopPagoMesModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('obtenerTopPagosCreadorMes -> error: $e');
      return [];
    }
  }

  /// Sube una imagen al bucket `chat-media` y devuelve una URL pública o firmada.
  /// pathHint: carpeta lógica (e.g., chatId) para organizar uploads.
  Future<String?> uploadChatImage({
    required Uint8List bytes,
    required String fileName,
    String? pathHint,
    String contentType = 'image/jpeg',
    Duration signedUrlTTL = const Duration(days: 7),
  }) async {
    try {
      final bucket = client.storage.from('chat-media');
      final objectPath = (pathHint != null && pathHint.isNotEmpty)
          ? '$pathHint/$fileName'
          : fileName;

      await bucket.uploadBinary(
        objectPath,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );

      // Prefer signed URL to work for private buckets
      try {
        final signed = await bucket.createSignedUrl(objectPath, signedUrlTTL.inSeconds);
        if (signed.isNotEmpty) return signed;
      } catch (_) {
        // ignore and try public url
      }

      // Fallback to public URL (if bucket is public)
      final publicUrl = bucket.getPublicUrl(objectPath);
      if (publicUrl.isNotEmpty) return publicUrl;

      return null;
    } catch (e) {
      debugPrint('uploadChatImage -> error: $e');
      return null;
    }
  }
}
