class MessageEntity {
  final String? idMensaje;
  final String idChat;
  final String idRemitente;
  final String contenido;
  final String? fechaEnvio;

  MessageEntity({
    this.idMensaje,
    required this.idChat,
    required this.idRemitente,
    required this.contenido,
    this.fechaEnvio,
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

