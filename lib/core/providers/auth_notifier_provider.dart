import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import 'auth_notifier.dart';
import 'auth_repository_provider.dart';

/// Se activa en `true` cuando Supabase emite el evento [passwordRecovery].
/// El widget raíz escucha este provider y navega a la pantalla de reset.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});