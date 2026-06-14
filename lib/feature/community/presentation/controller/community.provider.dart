import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/creator_repository_provider.dart';

final communityControllerProvider =
StateNotifierProvider<CommunityController, CommunityState>((ref) {
  final repo = ref.read(creatorRepositoryProvider);
  return CommunityController(repo);
});