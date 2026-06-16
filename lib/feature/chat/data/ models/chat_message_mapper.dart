import '../../../../domain/entities/message.dart';
import '../../presentation/pages/chat.page.dart';

class ChatMessageMapper {
  static ChatMessage fromEntity({
    required MessageEntity e,
    required String? currentUserId,
  }) {
    final isFromMe = currentUserId != null && currentUserId == e.idRemitente;

    DateTime ts;
    try {
      ts = e.fechaEnvio != null && e.fechaEnvio!.isNotEmpty
          ? DateTime.parse(e.fechaEnvio!)
          : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    final images = e.multimedia.map((m) => m.url).toList();

    return ChatMessage(
      id: e.idMensaje ?? '',
      text: e.contenido,
      timestamp: ts,
      fromMe: isFromMe,
      images: images,
    );
  }
}