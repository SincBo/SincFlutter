import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/core/providers/payment_repository_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_notifier_provider.dart';
import 'chat_repository_provider.dart';
import 'creator_repository_provider.dart';


/// ----------------------
/// SUPABASE CLIENT
/// ----------------------
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});


/// ----------------------
/// DATASOURCE
/// ----------------------
final supabaseDataSourceProvider = Provider<SupabaseDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return SupabaseDataSource(client);
});


/// ----------------------
/// AUTH REPOSITORY
/// ----------------------
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final ds = ref.read(supabaseDataSourceProvider);
  return AuthRepositoryImpl(ds);
});


/// ----------------------
/// AUTH NOTIFIER PROVIDER
/// ----------------------
/// FIXED: Correct function syntax () { ... }
/// FIXED: Correct import for StateNotifierProvider



/// ----------------------
/// CREATOR REPOSITORY
/// ----------------------



/// ----------------------
/// PROVIDER: Fetch creators
/// ----------------------
final creatorsProvider = FutureProvider((ref) async {
  final user = ref.watch(authNotifierProvider).value;

  // 🔥 SI NO HAY USUARIO → NO HACER NADA
  if (user == null) return [];

  final repo = ref.read(creatorRepositoryProvider);
  return await repo.getCreators();
});


/// ----------------------
/// SEARCH PROVIDER
/// ----------------------



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
/// MESSAGES PROVIDER
/// ----------------------
final messagesProvider =
FutureProvider.family<List<MessageModel>, String>((ref, idChat) async {
  final repo = ref.read(chatRepositoryProvider);

  return await repo.getMessages(idChat);
});


/// ----------------------
/// CHATS SUBSCRIBED PROVIDER
/// ----------------------

