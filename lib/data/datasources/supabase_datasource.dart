import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/creator_model.dart';
import '../models/message_model.dart';
import '../models/chat_con_creador_model.dart';
import '../utils/safe_map.dart';

class SupabaseDataSource {
  final SupabaseClient client;

  SupabaseDataSource(this.client);

  Future<UserModel?> signInWithEmail(String email, String password) async {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) return null;
    return UserModel.fromUser(user);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  UserModel? getCurrentUser() {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return UserModel.fromUser(user);
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
      debugPrint('buscarCreadores -> query: "$query", limit: $limit, offset: $offset');
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
          debugPrint('buscarCreadores -> empty result from table (empty query), attempting fallback to RPC');
          final rpcRes = await client.rpc('obtener_creadores');
          if (rpcRes is List) {
            final rpcList = rpcRes.map((e) => normalizeKeys(mapFromDynamic(e))).toList();
            final mapped = rpcList.map((m) => CreatorModel.fromMap(m)).toList();
            debugPrint('buscarCreadores -> fallback returned ${mapped.length} items (RPC for empty query)');
            return mapped;
          }
        }
        debugPrint('buscarCreadores -> returned ${result.length} items (empty query)');
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
        debugPrint('buscarCreadores -> raw is null or empty from table (query: "$query"). Attempting fallback to RPC obtener_creadores');
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
          debugPrint('buscarCreadores -> fallback returned ${mapped.length} items (RPC)');
          return mapped;
        }
        return [];
      }
      final result = list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return CreatorModel.fromMap(map);
      }).toList();
      debugPrint('buscarCreadores -> returned ${result.length} items (query)');
      return result;
    } catch (e) {
      debugPrint('buscarCreadores -> error: $e');
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
        debugPrint('estaSuscrito -> usuario no autenticado');
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
      debugPrint('estaSuscrito -> error: $e');
      return false;
    }
  }

  /// Creates a chat and its participants by calling the Postgres RPC
  /// `crear_chat_y_participantes(id_usuario, id_creador)` and returns the
  /// created chat id as a String, or null on failure.
  Future<String?> crearChatYParticipantes(String idCreador) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('crearChatYParticipantes -> usuario no autenticado');
        return null;
      }

      final rpcRes = await client.rpc('crear_chat_y_participantes', params: {
        'id_usuario': user.id,
        'id_creador': idCreador,
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

      debugPrint('crearChatYParticipantes -> unexpected rpcRes shape: $rpcRes');
      return null;
    } catch (e) {
      debugPrint('crearChatYParticipantes -> error: $e');
      return null;
    }
  }

  /// Sends a message via the Postgres RPC `enviar_mensaje(id_chat_param, id_remitente_param, contenido_param)`.
  /// Returns true on success, false on failure (including unauthenticated user).
  Future<bool> enviarMensaje(String idChat, String contenido) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('enviarMensaje -> usuario no autenticado');
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
      debugPrint('enviarMensaje -> error: $e');
      return false;
    }
  }

  /// Obtiene los chats a los que el usuario está suscrito llamando al RPC
  /// `obtener_chats_suscritos(id_usuario_input)` y devolviendo una lista de modelos.
  Future<List<ChatConCreadorModel>> obtenerChatsSuscritos() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('obtenerChatsSuscritos -> usuario no autenticado');
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
      debugPrint('obtenerChatsSuscritos -> error: $e');
      return [];
    }
  }

  /// Fetch messages for a chat (ordered ascending by fecha_envio)
  Future<List<MessageModel>> obtenerMensajes(String idChat) async {
    try {
      // Supabase Dart: use named parameter `ascending: true` to order ascending
      final res = await client.from('mensaje').select().eq('id_chat', idChat).order('fecha_envio', ascending: true);

      List<dynamic> list;
      try {
        list = List<dynamic>.from(res);
      } catch (_) {
        list = <dynamic>[];
      }

      final messages = list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return MessageModel.fromMap(map);
      }).toList();

      return messages;
    } catch (e) {
      debugPrint('obtenerMensajes -> error: $e');
      return [];
    }
  }

  /// Insert a message into `mensaje` table returning the created row as MessageModel
  Future<MessageModel?> insertarMensaje(String idChat, String contenido) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        debugPrint('insertarMensaje -> usuario no autenticado');
        return null;
      }

      // Insert and return the inserted row(s)
      final res = await client.from('mensaje').insert({
        'id_chat': idChat,
        'id_remitente': user.id,
        'contenido': contenido,
      }).select();

      if (res == null) return null;

      // Supabase typically returns a list with the inserted row
      if (res is List && res.isNotEmpty) {
        final map = normalizeKeys(mapFromDynamic(res.first));
        return MessageModel.fromMap(map);
      }

      if (res is Map) {
        final map = normalizeKeys(mapFromDynamic(res));
        return MessageModel.fromMap(map);
      }

      debugPrint('insertarMensaje -> unexpected response shape: $res');
      return null;
    } catch (e) {
      debugPrint('insertarMensaje -> error: $e');
      return null;
    }
  }

}
