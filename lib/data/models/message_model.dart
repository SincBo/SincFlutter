import '../utils/safe_map.dart';

class MessageModel {
  final String? idMensaje;
  final String idChat;
  final String idRemitente;
  final String contenido;
  final String? fechaEnvio; // mantener como String para reflejar el backend

  MessageModel({
    this.idMensaje,
    required this.idChat,
    required this.idRemitente,
    required this.contenido,
    this.fechaEnvio,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final m = normalizeKeys(map);
    return MessageModel(
      idMensaje: getStringFromMap(m, ['id_mensaje', 'idMensaje', 'idMensaje']),
      idChat: getStringFromMap(m, ['id_chat', 'idChat']) ,
      idRemitente: getStringFromMap(m, ['id_remitente', 'idRemitente', 'remitente']),
      contenido: getStringFromMap(m, ['contenido', 'contenido_mensaje', 'content', 'mensaje']),
      fechaEnvio: getStringFromMap(m, ['fecha_envio', 'fechaEnvio', 'sent_at']).isNotEmpty
          ? getStringFromMap(m, ['fecha_envio', 'fechaEnvio', 'sent_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_mensaje': idMensaje,
      'id_chat': idChat,
      'id_remitente': idRemitente,
      'contenido': contenido,
      'fecha_envio': fechaEnvio,
    };
  }
}

