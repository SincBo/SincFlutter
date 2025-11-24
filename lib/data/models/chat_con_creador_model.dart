import '../../domain/entities/chat_con_creador.dart';
import '../utils/safe_map.dart';

class ChatConCreadorModel extends ChatConCreadorEntity {
  ChatConCreadorModel({
    required String idChat,
    required String idCreador,
    required String nombreCreador,
  }) : super(idChat: idChat, idCreador: idCreador, nombreCreador: nombreCreador);

  factory ChatConCreadorModel.fromMap(Map<String, dynamic> map) {
    final nm = normalizeKeys(map);
    return ChatConCreadorModel(
      idChat: nm['id_chat'] as String? ?? nm['idChat'] as String? ?? '',
      idCreador: nm['id_creador'] as String? ?? nm['idCreador'] as String? ?? '',
      nombreCreador: nm['nombre_creador'] as String? ?? nm['nombreCreador'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id_chat': idChat,
        'id_creador': idCreador,
        'nombre_creador': nombreCreador,
      };
}

