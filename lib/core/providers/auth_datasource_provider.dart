import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authDataSourceProvider = Provider<SupabaseDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseDataSource(client);
});