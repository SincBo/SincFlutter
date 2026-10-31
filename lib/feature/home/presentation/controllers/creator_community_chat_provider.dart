import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_notifier_provider.dart';
import '../../../../core/providers/chat_repository_provider.dart';
import '../../../../core/providers/creator_repository_provider.dart';
import '../../../../domain/entities/creator.dart';

/// Resultado del provider: el id del chat de comunidad y el creador.
typedef CreatorChatResult = ({String chatId, CreatorEntity creator});

/// Busca (o crea) el chat de comunidad (broadcast) del creador autenticado.
///
/// - Busca al usuario actual dentro de la lista de creadores.
/// - Si no aparece ahí (por ejemplo, perfil recién creado), arma un
///   [CreatorEntity] mínimo a partir del perfil de auth.
/// - Usa [ChatRepository.getOrCreateComunidadChat], que ya existe en el
///   repositorio actual del proyecto.
final creatorCommunityChatProvider =
    FutureProvider<CreatorChatResult?>((ref) async {
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) return null;

  final creatorRepo = ref.read(creatorRepositoryProvider);
  final chatRepo = ref.read(chatRepositoryProvider);

  // Buscar al usuario actual dentro de la lista de creadores
  final creators = await creatorRepo.getCreators();
  final matches = creators.where((c) => c.idUsuario == user.id);
  final CreatorEntity me = matches.isNotEmpty
      ? matches.first
      : CreatorEntity(
          idUsuario: user.id,
          nombreUsuario: (user.username != null && user.username!.isNotEmpty)
              ? user.username!
              : (user.email?.split('@').first ?? 'Creador'),
          email: user.email ?? '',
          bio: '',
          precioSuscripcion: 0,
          precioSuscripcionFellow: 0,
        );

  final chatId = await chatRepo.getOrCreateComunidadChat(me.idUsuario);
  if (chatId == null) return null;

  return (chatId: chatId, creator: me);
});
