import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/data/datasources/auth.datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthDataSource(client);
});