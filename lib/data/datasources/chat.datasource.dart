import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_con_creador_model.dart';
import '../models/message_model.dart';
import '../utils/safe_map.dart';

class ChatDataSource {
  final SupabaseClient client;

  ChatDataSource(this.client);

  // =====================================================
  // CHATS
  // =====================================================

  /// Obtiene los chats del usuario autenticado
  Future<List<ChatConCreadorModel>> getChatsSuscritos() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final res = await client.rpc(
      'obtener_chats_suscritos',
      params: {'id_usuario_input': user.id},
    );

    final list = _parseList(res);

    return list
        .map((e) => ChatConCreadorModel.fromMap(e))
        .toList();
  }

  /// Crea o obtiene un chat de comunidad para un creador
  Future<String?> getOrCreateComunidadChat(String idCreador) async {
    final existing = await client
        .from('chat')
        .select('id_chat')
        .eq('id_creador', idCreador)
        .maybeSingle();

    if (existing != null) {
      return existing['id_chat']?.toString();
    }

    final inserted = await client
        .from('chat')
        .insert({'id_creador': idCreador})
        .select('id_chat')
        .single();

    return inserted['id_chat']?.toString();
  }

  // =====================================================
  // MESSAGES
  // =====================================================

  /// Obtener mensajes de un chat
  Future<List<MessageModel>> getMessages(String chatId) async {
    final res = await client
        .from('mensaje')
        .select('*, mensaje_multimedia(*)')
        .eq('id_chat', chatId)
        .order('fecha_envio', ascending: false);

    final list = _parseList(res);

    return list.map((map) {
      final mediaRaw = map['mensaje_multimedia'] as List? ?? [];

      final media = mediaRaw.map((m) {
        return MensajeMultimediaModel.fromMap(_normalize(m));
      }).toList();

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
  }

  /// Insertar mensaje de texto
  Future<MessageModel?> insertMessage(
      String chatId,
      String contenido,
      ) async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final res = await client
        .from('mensaje')
        .insert({
      'id_chat': chatId,
      'id_remitente': user.id,
      'contenido': contenido,
    })
        .select()
        .maybeSingle();

    if (res == null) return null;

    return MessageModel.fromMap(_normalize(res));
  }

  /// Enviar mensaje vía RPC (si lo necesitas)
  Future<bool> sendMessageRpc(
      String chatId,
      String contenido,
      ) async {
    final user = client.auth.currentUser;
    if (user == null) return false;

    await client.rpc('enviar_mensaje', params: {
      'id_chat_param': chatId,
      'id_remitente_param': user.id,
      'contenido_param': contenido,
    });

    return true;
  }

  // =====================================================
  // MULTIMEDIA MESSAGES
  // =====================================================

  /// Mensaje con imágenes
  Future<String?> sendMessageWithImages({
    required String chatId,
    required String text,
    required List<String> imageUrls,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    final res = await client.rpc('enviar_mensaje_con_imagenes', params: {
      'p_id_chat': chatId,
      'p_contenido': text,
      'p_urls': imageUrls,
    });

    return _extractString(res);
  }

  // =====================================================
  // HELPERS
  // =====================================================

  List<Map<String, dynamic>> _parseList(dynamic res) {
    if (res == null) return [];

    if (res is List) {
      return res.map((e) => _normalize(e)).toList();
    }

    if (res is Map) {
      return [_normalize(res)];
    }

    return [];
  }

  Map<String, dynamic> _normalize(dynamic value) {
    return normalizeKeys(mapFromDynamic(value));
  }

  String? _extractString(dynamic res) {
    if (res == null) return null;
    if (res is String) return res;
    if (res is num) return res.toString();
    if (res is List && res.isNotEmpty) {
      return _extractString(res.first);
    }
    if (res is Map) {
      for (final v in res.values) {
        final r = _extractString(v);
        if (r != null) return r;
      }
    }
    return null;
  }
}