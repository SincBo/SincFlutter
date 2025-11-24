import '../entities/creator.dart';
import '../entities/message.dart';
import '../entities/chat_con_creador.dart';

abstract class CreatorRepository {
  Future<List<CreatorEntity>> obtenerCreadores();
  Future<List<CreatorEntity>> buscarCreadores(String query, {int limit = 50, int offset = 0});

  /// Verifica si el usuario autenticado está suscrito al creador dado.
  Future<bool> estaSuscrito(String idCreador);

  /// Crea (si no existe) un chat entre el usuario autenticado y el creador,
  /// y registra los participantes. Devuelve el id del chat o null si falla.
  Future<String?> crearChatYParticipantes(String idCreador);

  /// Obtiene los mensajes de un chat por su id (orden ascendente por fecha).
  Future<List<MessageEntity>> obtenerMensajes(String idChat);

  /// Inserta un mensaje en el chat (autor: usuario autenticado). Devuelve el mensaje guardado o null en fallo.
  Future<MessageEntity?> insertarMensaje(String idChat, String contenido);

  /// Envía un mensaje usando el RPC 'enviar_mensaje'. Devuelve true si se envió correctamente.
  Future<bool> enviarMensaje(String idChat, String contenido);

  /// Obtiene los chats suscritos para el usuario autenticado.
  Future<List<ChatConCreadorEntity>> obtenerChatsSuscritos();
}
