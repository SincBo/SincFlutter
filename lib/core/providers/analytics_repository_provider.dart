import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/analytics_repository.dart';
import 'analytics_datasoruce_provider.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final ds = ref.watch(analyticsDataSourceProvider);
  return AnalyticsRepository(ds);
});