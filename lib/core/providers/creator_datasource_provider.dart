import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/creator.datasource.dart';
import 'auth_datasource_provider.dart';

final creatorDataSourceProvider = Provider<CreatorDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return CreatorDataSource(client);
});