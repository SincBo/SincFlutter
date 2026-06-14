import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import 'auth_notifier.dart';
import 'auth_repository_provider.dart';

final authNotifierProvider =
StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return AuthNotifier(repo);
});