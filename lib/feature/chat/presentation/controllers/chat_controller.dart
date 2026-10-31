import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_notifier_provider.dart';
import '../../../../data/models/message_model.dart';
import '../../data/ models/chat_message_mapper.dart';
import '../pages/chat.page.dart';
class ChatController {
  final Ref ref;

  ChatController(this.ref);

  String? get currentUserId {
    return ref.read(authNotifierProvider)
        .maybeWhen(data: (u) => u?.id, orElse: () => null);
  }

  List<ChatMessage> mapMessages(List<MessageModel> list) {
    final uid = currentUserId;

    return list.map((e) {
      // ✅ 1. FROM ME
      final isFromMe = uid != null && uid == e.idRemitente;

      // ✅ 2. TIMESTAMP
      DateTime ts;
      try {
        ts = e.fechaEnvio != null && e.fechaEnvio!.isNotEmpty
            ? DateTime.parse(e.fechaEnvio!)
            : DateTime.now();
      } catch (_) {
        ts = DateTime.now();
      }

      // ✅ 3. IMAGES
      final images = e.multimedia.map((m) => m.url).toList();

      // ✅ 4. BUILD UI MODEL
      return ChatMessage(
        id: e.idMensaje ?? '',
        text: e.contenido,
        timestamp: ts,
        fromMe: isFromMe,
        images: images,
      );
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  bool canSendMessage(bool isCommunityChat, bool isCreator) {
    if (!isCommunityChat) return true;
    return isCreator;
  }

  /// Solo el creador puede mandar imágenes/media, en cualquier tipo de
  /// chat (comunidad o fellow/DM). El backend (enviar_mensaje_con_imagenes)
  /// ya lo exige del lado servidor; esto solo evita mostrar el botón.
  bool canSendImage(bool isCreator) => isCreator;
}