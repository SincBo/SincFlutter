import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sincboflutter/core/providers/payment_datasource_provider.dart';
import '../../domain/repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final ds = ref.watch(paymentDataSourceProvider);
  return PaymentRepository(ds);
});