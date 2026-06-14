import 'dart:typed_data';

import 'package:sincboflutter/data/models/message_model.dart';

import '../../data/datasources/chat.datasource.dart';
import '../../data/datasources/storage.datasource.dart';
import '../../domain/entities/chat_con_creador.dart';
import '../../domain/entities/message.dart';

class ChatRepository {
  final ChatDataSource chatDs;
  final StorageDataSource storageDs;

  ChatRepository({
    required this.chatDs,
    required this.storageDs,
  });

  // =========================
  // CHATS
  // =========================
  Future<List<ChatConCreadorEntity>> getChatsSuscritos() {
    return chatDs.obtenerChatsSuscritos();
  }

  Future<String?> getOrCreateComunidadChat(String creatorId) {
    return chatDs.getOrCreateComunidadChatCreador(creatorId);
  }

  // =========================
  // MENSAJES
  // =========================
  Future<List<MessageModel>> getMessages(String chatId) {
    return chatDs.obtenerMensajes(chatId);
  }

  Future<MessageModel?> sendTextMessage({
    required String chatId,
    required String text,
  }) {
    return chatDs.insertarMensaje(chatId, text);
  }

  Future<bool> sendMessageRPC({
    required String chatId,
    required String text,
  }) {
    return chatDs.enviarMensaje(chatId, text);
  }

  // =========================
  // MENSAJES CON IMAGENES (ORQUESTACIÓN REAL)
  // =========================
  Future<String?> sendMessageWithImages({
    required String chatId,
    required String text,
    required List<Uint8List> images,
  }) async {
    try {
      final uploadedUrls = <String>[];

      for (final img in images) {
        final url = await storageDs.uploadChatImage(
          bytes: img,
          fileName:
          '${DateTime.now().millisecondsSinceEpoch}_${uploadedUrls.length}.jpg',
          pathHint: chatId,
        );

        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      if (uploadedUrls.isEmpty) {
        // fallback: enviar solo texto si falla upload
        await chatDs.enviarMensaje(chatId, text);
        return null;
      }

      return await chatDs.enviarMensajeConImagenes(
        chatId: chatId,
        text: text,
        imageUrls: uploadedUrls,
      );
    } catch (e) {
      return null;
    }
  }

  // =========================
  // STREAM / FUTURO EXTENSIBLE
  // =========================
  Future<bool> sendSimpleMessage({
    required String chatId,
    required String text,
  }) async {
    return await chatDs.enviarMensaje(chatId, text);
  }

  Future<bool> sendImageMessage({
    required String chatId,
    required List<String> urls,
  }) async {
    try {
      final res = await chatDs.enviarMensajeConImagenes(
        chatId: chatId,
        text: '',
        imageUrls: urls,
      );
      return res != null && res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> createChatAndParticipants(String creatorId, String idPlan, bool isCreator) {
    return chatDs.crearChatYParticipantes(creatorId, idPlan, isCreator);
  }
}