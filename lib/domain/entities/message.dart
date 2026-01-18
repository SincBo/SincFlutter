class MessageEntity {
  final String? idMensaje;
  final String idChat;
  final String idRemitente;
  final String contenido;
  final String? fechaEnvio;
  final List<MensajeMultimediaEntity> multimedia;


  MessageEntity({
    this.idMensaje,
    required this.idChat,
    required this.idRemitente,
    required this.contenido,
    this.fechaEnvio,
    this.multimedia = const [],
  });

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


class MensajeMultimediaEntity {
  final String id;
  final String tipo; // 'imagen' | 'video'
  final String url;  // puede ser url pública o path storage
  final String? createdAt;

  MensajeMultimediaEntity({
    required this.id,
    required this.tipo,
    required this.url,
    this.createdAt,
  });
}
