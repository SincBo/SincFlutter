import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/analytics.datasources.dart';
import 'auth_datasource_provider.dart';

final analyticsDataSourceProvider = Provider<AnalyticsDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return AnalyticsDataSource(client);
});