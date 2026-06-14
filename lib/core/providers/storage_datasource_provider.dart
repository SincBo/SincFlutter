import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/storage.datasource.dart';
import 'auth_datasource_provider.dart';


final storageDataSourceProvider = Provider<StorageDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return StorageDataSource(client);
});