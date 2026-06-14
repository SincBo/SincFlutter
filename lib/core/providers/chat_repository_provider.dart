import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/core/providers/storage_datasource_provider.dart';

import '../../domain/repositories/chat_repository.dart';
import 'chat_datasource_provider.dart';


final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final chatDs = ref.read(chatDataSourceProvider);
  final storageDs = ref.read(storageDataSourceProvider);

  return ChatRepository(
    chatDs: chatDs,
    storageDs: storageDs,
  );
});