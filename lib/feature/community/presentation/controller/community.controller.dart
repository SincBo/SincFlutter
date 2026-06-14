import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/repositories/creator_repository.dart';
import 'community.state.dart';

class CommunityController extends StateNotifier<CommunityState> {
  final CreatorRepository repo;

  CommunityController(this.repo) : super(const CommunityState());

  static const int pageSize = 20;
  int _page = 0;

  Future<void> refresh(String query) async {
    _page = 0;

    state = state.copyWith(
      loading: true,
      creators: [],
      hasMore: true,
      query: query,
    );

    final results = await repo.searchCreators(query, limit: pageSize, offset: 0);

    state = state.copyWith(
      creators: results,
      loading: false,
      hasMore: results.length == pageSize,
    );

    _page = 1;
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;

    state = state.copyWith(loadingMore: true);

    final results = await repo.searchCreators(
      state.query,
      limit: pageSize,
      offset: _page * pageSize,
    );

    state = state.copyWith(
      creators: [...state.creators, ...results],
      loadingMore: false,
      hasMore: results.length == pageSize,
    );

    _page++;
  }
}