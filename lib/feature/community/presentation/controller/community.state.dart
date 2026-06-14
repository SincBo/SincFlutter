import '../../../../domain/entities/creator.dart';

class CommunityState {
  final List<CreatorEntity> creators;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String query;

  const CommunityState({
    this.creators = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.query = '',
  });

  CommunityState copyWith({
    List<CreatorEntity>? creators,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? query,
  }) {
    return CommunityState(
      creators: creators ?? this.creators,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      query: query ?? this.query,
    );
  }
}