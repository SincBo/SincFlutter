import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/datasources/supabase_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/creator_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/creator_repository.dart';
import '../domain/entities/user.dart';
import '../domain/entities/creator.dart';
import '../domain/entities/message.dart';
import '../domain/entities/chat_con_creador.dart';
import '../providers/auth_notifier.dart';


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
final authNotifierProvider =
StateNotifierProvider<AuthStateNotifier, AsyncValue<UserEntity?>>(
      (ref) {
    final repo = ref.read(authRepositoryProvider);
    return AuthStateNotifier(repo);
  },
);


/// ----------------------
/// CREATOR REPOSITORY
/// ----------------------
final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  final ds = ref.read(supabaseDataSourceProvider);
  return CreatorRepositoryImpl(ds);
});


/// ----------------------
/// PROVIDER: Fetch creators
/// ----------------------
final creatorsProvider = FutureProvider<List<CreatorEntity>>((ref) async {
  final repo = ref.read(creatorRepositoryProvider);
  return repo.obtenerCreadores();
});


/// ----------------------
/// SEARCH PROVIDER
/// ----------------------
final creatorsSearchProvider =
FutureProvider.family<List<CreatorEntity>, String>((ref, query) async {
  final repo = ref.read(creatorRepositoryProvider);
  return repo.buscarCreadores(query);
});


/// ----------------------
/// IS SUBSCRIBED PROVIDER
/// ----------------------
final isSubscribedProvider =
FutureProvider.family<bool, String>((ref, idCreador) async {
  final repo = ref.read(creatorRepositoryProvider);
  try {
    return await repo.estaSuscrito(idCreador);
  } catch (e) {
    debugPrint('isSubscribedProvider -> error: $e');
    return false;
  }
});


/// ----------------------
/// MESSAGES PROVIDER
/// ----------------------
final messagesProvider =
FutureProvider.family<List<MessageEntity>, String>((ref, idChat) async {
  final repo = ref.read(creatorRepositoryProvider);
  try {
    return await repo.obtenerMensajes(idChat);
  } catch (e) {
    debugPrint('messagesProvider -> error: $e');
    return <MessageEntity>[];
  }
});


/// ----------------------
/// CHATS SUBSCRIBED PROVIDER
/// ----------------------
final chatsSuscritosProvider =
FutureProvider<List<ChatConCreadorEntity>>((ref) async {
  final repo = ref.read(creatorRepositoryProvider);
  try {
    return await repo.obtenerChatsSuscritos();
  } catch (e) {
    debugPrint('chatsSuscritosProvider -> error: $e');
    return <ChatConCreadorEntity>[];
  }
});
