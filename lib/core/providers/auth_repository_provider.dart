import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'auth_datasource_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final datasource = ref.watch(authDataSourceProvider);
  return AuthRepositoryImpl(datasource);
});