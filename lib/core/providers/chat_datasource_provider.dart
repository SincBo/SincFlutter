import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/chat.datasource.dart';
import 'auth_datasource_provider.dart';

final chatDataSourceProvider = Provider<ChatDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return ChatDataSource(client);
});