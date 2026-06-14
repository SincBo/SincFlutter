import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/creator_repository.dart';
import 'creator_datasource_provider.dart';

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  final ds = ref.watch(creatorDataSourceProvider);
  return CreatorRepository(ds);
});