import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/paymente.datasource.dart';
import 'auth_datasource_provider.dart';

final paymentDataSourceProvider = Provider<PaymentDataSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return PaymentDataSource(client);
});