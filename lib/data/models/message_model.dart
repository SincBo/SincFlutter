import '../utils/safe_map.dart';

class MessageModel {
  final String? idMensaje;
  final String idChat;
  final String idRemitente;
  final String contenido;
  final String? fechaEnvio; // mantener como String para reflejar el backend
  // 🆕 adjuntos
  final List<MensajeMultimediaModel> multimedia;

  MessageModel({
    this.idMensaje,
    required this.idChat,
    required this.idRemitente,
    required this.contenido,
    this.fechaEnvio,
    this.multimedia = const [],
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final m = normalizeKeys(map);

    // 👇 parsear multimedia si existe
    final rawMedia = m['mensaje_multimedia'];
    final List<MensajeMultimediaModel> mediaList =
    rawMedia is List
        ? rawMedia
        .map((e) => MensajeMultimediaModel.fromMap(
      normalizeKeys(mapFromDynamic(e)),
    ))
        .toList()
        : [];

    return MessageModel(
      idMensaje: getStringFromMap(m, ['id_mensaje']),
      idChat: getStringFromMap(m, ['id_chat']),
      idRemitente: getStringFromMap(m, ['id_remitente', 'remitente']),
      contenido: getStringFromMap(m, ['contenido', 'content', 'mensaje']),
      fechaEnvio: getStringFromMap(m, ['fecha_envio']).isNotEmpty
          ? getStringFromMap(m, ['fecha_envio'])
          : null,
      multimedia: mediaList,
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

class MensajeMultimediaModel {
  final String id;
  final String tipo; // 'imagen'
  final String url;
  final String? createdAt;

  MensajeMultimediaModel({
    required this.id,
    required this.tipo,
    required this.url,
    this.createdAt,
  });

  factory MensajeMultimediaModel.fromMap(Map<String, dynamic> map) {
    final m = normalizeKeys(map);
    return MensajeMultimediaModel(
      id: getStringFromMap(m, ['id_mensaje_multimedia', 'id']),
      tipo: getStringFromMap(m, ['tipo']),
      url: getStringFromMap(m, ['url']),
      createdAt: getStringFromMap(m, ['created_at', 'createdAt']).isNotEmpty
          ? getStringFromMap(m, ['created_at', 'createdAt'])
          : null,
    );
  }
}

