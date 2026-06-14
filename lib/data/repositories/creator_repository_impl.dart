import 'package:flutter/cupertino.dart';

import '../../domain/entities/chat_con_creador.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/creator_repository.dart';
import '../datasources/supabase_datasource.dart';

class CreatorRepositoryImpl {
  // final SupabaseDataSource datasource;
  //
  // CreatorRepositoryImpl(this.datasource);
  //
  // @override
  // Future<List<CreatorEntity>> obtenerCreadores() async {
  //   final models = await datasource.obtenerCreadores();
  //   // CreatorModel extends CreatorEntity so cast is fine
  //   return models.cast<CreatorEntity>();
  // }
  //
  // @override
  // Future<List<CreatorEntity>> buscarCreadores(String query,
  //     {int limit = 50, int offset = 0}) async {
  //   final models = await datasource.buscarCreadores(query,
  //       limit: limit, offset: offset);
  //   return models.cast<CreatorEntity>();
  // }
  //
  // @override
  // Future<bool> estaSuscrito(String idCreador) async {
  //   return await datasource.estaSuscrito(idCreador);
  // }
  //
  // @override
  // Future<bool> esSuscriptorDePlan(String idPlan) async {
  //   return await datasource.esSuscriptorDePlan(idPlan);
  // }
  //
  // @override
  // Future<String?> crearChatYParticipantes(String idCreador, String idPlan, bool isCreator) async {
  //   try {
  //     return await datasource.crearChatYParticipantes(idCreador, idPlan, isCreator);
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.crearChatYParticipantes -> error: $e');
  //     return null;
  //   }
  // }
  //
  // @override
  // Future<String?> getOrCreateComunidadChatCreador(String idCreador) async {
  //   try {
  //     return await datasource.getOrCreateComunidadChatCreador(idCreador);
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.getOrCreateComunidadChatCreador -> error: $e');
  //     return null;
  //   }
  // }
  //
  // @override
  // Future<List<MessageEntity>> obtenerMensajes(String idChat) async {
  //   final models = await datasource.obtenerMensajes(idChat);
  //   return models.map((m) => MessageEntity(
  //     idMensaje: m.idMensaje,
  //     idChat: m.idChat,
  //     idRemitente: m.idRemitente,
  //     contenido: m.contenido,
  //     fechaEnvio: m.fechaEnvio,
  //     multimedia: m.multimedia.map((mm) => MensajeMultimediaEntity(
  //       id: mm.id,
  //       tipo: mm.tipo,
  //       url: mm.url,
  //       createdAt: mm.createdAt,
  //     )).toList(),
  //   )).toList();
  // }
  //
  // @override
  // Future<MessageEntity?> insertarMensaje(String idChat, String contenido) async {
  //   try {
  //     final model = await datasource.insertarMensaje(idChat, contenido);
  //     if (model == null) return null;
  //     return MessageEntity(
  //       idMensaje: model.idMensaje,
  //       idChat: model.idChat,
  //       idRemitente: model.idRemitente,
  //       contenido: model.contenido,
  //       fechaEnvio: model.fechaEnvio,
  //       multimedia: const [],
  //     );
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.insertarMensaje -> error: $e');
  //     return null;
  //   }
  // }
  //
  // @override
  // Future<bool> enviarMensaje(String idChat, String contenido) async {
  //   try {
  //     return await datasource.enviarMensaje(idChat, contenido);
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.enviarMensaje -> error: $e');
  //     return false;
  //   }
  // }
  //
  // @override
  // Future<String?> enviarMensajeConImagenes(String idChat, String texto, List<String> imageUrls) async {
  //   try {
  //     return await datasource.enviarMensajeConImagenes(chatId: idChat, text: texto, imageUrls: imageUrls);
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.enviarMensajeConImagenes -> error: $e');
  //     return null;
  //   }
  // }
  //
  // @override
  // Future<List<ChatConCreadorEntity>> obtenerChatsSuscritos() async {
  //   try {
  //     final models = await datasource.obtenerChatsSuscritos();
  //     return models.map((m) => ChatConCreadorEntity(
  //       idChat: m.idChat,
  //       idCreador: m.idCreador,
  //       nombreCreador: m.nombreCreador,
  //     )).toList();
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.obtenerChatsSuscritos -> error: $e');
  //     return [];
  //   }
  // }
  //
  // @override
  // Future<String?> createTransaction({required String creatorId, required String planId, required double price}) async {
  //   try {
  //     return await datasource.createTransaction(creatorId: creatorId, planId: planId, price: price);
  //   } catch (e) {
  //     debugPrint('CreatorRepositoryImpl.createTransaction -> error: $e');
  //     return null;
  //   }
  // }
}
