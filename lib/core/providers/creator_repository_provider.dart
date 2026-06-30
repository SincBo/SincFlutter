import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/creator_repository_impl.dart';
import '../../domain/repositories/creator_repository.dart';
import 'creator_datasource_provider.dart';

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  final ds = ref.watch(creatorDataSourceProvider);
  return CreatorRepositoryImpl(ds);
});