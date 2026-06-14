import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_con_creador_model.dart';
import '../models/message_model.dart';
import '../utils/safe_map.dart';

class ChatDataSource {
  final SupabaseClient client;

  ChatDataSource(this.client);

  // =========================
  // GET CHATS SUSCRITOS
  // =========================
  Future<List<ChatConCreadorModel>> obtenerChatsSuscritos() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return [];

      final res = await client.rpc(
        'obtener_chats_suscritos',
        params: {'id_usuario_input': user.id},
      );

      if (res == null) return [];

      if (res is List) {
        return res.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return ChatConCreadorModel.fromMap(map);
        }).toList();
      }

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

  // =========================
  // CREATE / GET CHAT COMUNIDAD
  // =========================
  Future<String?> getOrCreateComunidadChatCreador(String idCreador) async {
    try {
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

      final inserted = await client
          .from('chat')
          .insert({'id_creador': idCreador})
          .select('id_chat')
          .single();

      final id = inserted['id_chat'];
      return id?.toString();
    } catch (e) {
      debugPrint('getOrCreateComunidadChatCreador -> error: $e');
      return null;
    }
  }

  // =========================
  // GET MENSAJES
  // =========================
  Future<List<MessageModel>> obtenerMensajes(String idChat) async {
    try {
      final res = await client
          .from('mensaje')
          .select('*, mensaje_multimedia(*)')
          .eq('id_chat', idChat)
          .order('fecha_envio', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);

      return list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));

        final mediaRaw = map['mensaje_multimedia'];

        final media = (mediaRaw is List)
            ? mediaRaw.map((m) {
          return MensajeMultimediaModel.fromMap(
            normalizeKeys(mapFromDynamic(m)),
          );
        }).toList()
            : <MensajeMultimediaModel>[];

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
      debugPrint('obtenerMensajes -> error: $e');
      return [];
    }
  }

  // =========================
  // INSERT MESSAGE (TEXT)
  // =========================
  Future<MessageModel?> insertarMensaje(
      String idChat,
      String contenido,
      ) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final res = await client.from('mensaje').insert({
        'id_chat': idChat,
        'id_remitente': user.id,
        'contenido': contenido,
      }).select();

      final rows = res as List<dynamic>;
      if (rows.isEmpty) return null;

      final map = normalizeKeys(mapFromDynamic(rows.first));
      return MessageModel.fromMap(map);
    } catch (e) {
      debugPrint('insertarMensaje -> error: $e');
      return null;
    }
  }

  // =========================
  // SEND MESSAGE VIA RPC
  // =========================
  Future<bool> enviarMensaje(
      String idChat,
      String contenido,
      ) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return false;

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

  // =========================
  // SEND MESSAGE WITH IMAGES
  // =========================
  Future<String?> enviarMensajeConImagenes({
    required String chatId,
    required String text,
    required List<String> imageUrls,
  }) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final res = await client.rpc('enviar_mensaje_con_imagenes', params: {
        'p_id_chat': chatId,
        'p_contenido': text,
        'p_urls': imageUrls,
      });

      String? parse(dynamic v) {
        if (v is String && v.isNotEmpty) return v;
        if (v is num) return v.toString();
        if (v is List && v.isNotEmpty) return parse(v.first);
        if (v is Map) {
          for (final e in v.values) {
            final r = parse(e);
            if (r != null) return r;
          }
        }
        return null;
      }

      return parse(res);
    } catch (e) {
      debugPrint('enviarMensajeConImagenes -> error: $e');
      return null;
    }
  }

  Stream<List<MessageModel>> watchMensajes(String idChat) {
    return client
        .from('mensaje')
        .stream(primaryKey: ['id_mensaje'])
        .eq('id_chat', idChat)
        .order('fecha_envio')
        .map((data) {
      return data.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return MessageModel.fromMap(map);
      }).toList();
    });
  }

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
}