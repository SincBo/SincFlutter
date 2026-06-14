import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/message_model.dart';
import '../../../domain/entities/chat_con_creador.dart';
import '../chat_repository_provider.dart';

final chatMessagesProvider =
FutureProvider.family<List<MessageModel>, String>(
      (ref, chatId) async {
    final repo = ref.read(chatRepositoryProvider);

    return repo.getMessages(chatId);
  },
);

final chatsProvider =
FutureProvider<List<ChatConCreadorEntity>>(
      (ref) async {
    final repo = ref.watch(chatRepositoryProvider);

    return repo.getChatsSuscritos();
  },
);