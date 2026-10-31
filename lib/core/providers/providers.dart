import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/core/providers/payment_repository_provider.dart';

import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/message_model.dart';
import 'auth_datasource_provider.dart';
import 'auth_notifier_provider.dart';
import 'chat_repository_provider.dart';
import 'creator_repository_provider.dart';

// Re-exportamos supabaseClientProvider para que los archivos que ya importan
// providers.dart no necesiten cambiar sus imports.
export 'auth_datasource_provider.dart' show supabaseClientProvider;

/// ----------------------
/// DATASOURCE LEGACY
/// ----------------------
/// TODO: migrar los usos de supabaseDataSourceProvider a datasources específicos
final supabaseDataSourceProvider = Provider<SupabaseDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseDataSource(client);
});

/// ----------------------
/// PROVIDER: Fetch creators
/// ----------------------
final creatorsProvider = FutureProvider((ref) async {
  final user = ref.watch(authNotifierProvider).value;
  if (user == null) return [];
  final repo = ref.read(creatorRepositoryProvider);
  return await repo.getCreators();
});

/// ----------------------
/// IS SUBSCRIBED PROVIDER
/// ----------------------
final isSubscribedProvider =
    FutureProvider.family<bool, String>((ref, idCreador) async {
  final repo = ref.read(paymentRepositoryProvider);
  try {
    return await repo.isSubscribedToCreator(idCreador);
  } catch (e) {
    debugPrint('isSubscribedProvider -> error: $e');
    return false;
  }
});

/// ----------------------
/// IS SUBSCRIBED TO PLAN PROVIDER (por plan, no solo por creador)
/// ----------------------
final isSubscribedToPlanProvider =
    FutureProvider.family<bool, String>((ref, idPlan) async {
  final repo = ref.read(paymentRepositoryProvider);
  try {
    return await repo.isSubscribedToPlan(idPlan);
  } catch (e) {
    debugPrint('isSubscribedToPlanProvider -> error: $e');
    return false;
  }
});

/// ----------------------
/// MESSAGES PROVIDER
/// ----------------------
final messagesProvider =
    FutureProvider.family<List<MessageModel>, String>((ref, idChat) async {
  final repo = ref.read(chatRepositoryProvider);
  return await repo.getMessages(idChat);
});

