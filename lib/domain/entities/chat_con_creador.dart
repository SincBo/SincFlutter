class ChatConCreadorEntity {
  final String idChat;
  final String idCreador;
  final String nombreCreador;

  ChatConCreadorEntity({
    required this.idChat,
    required this.idCreador,
    required this.nombreCreador,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_chat': idChat,
      'id_creador': idCreador,
      'nombre_creador': nombreCreador,
    };
  }
}

