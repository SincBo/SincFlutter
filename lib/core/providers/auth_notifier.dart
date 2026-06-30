import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_notifier_provider.dart';

class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository repository;
  final Ref _ref;

  StreamSubscription? _sub;

  AuthNotifier(this.repository, this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;

        if (event == AuthChangeEvent.passwordRecovery) {
          _ref.read(passwordRecoveryProvider.notifier).state = true;
          return;
        }

        // Resetear el flag si el usuario completa o cancela el recovery
        _ref.read(passwordRecoveryProvider.notifier).state = false;

        if (event == AuthChangeEvent.signedOut || data.session == null) {
          state = const AsyncValue.data(null);
          return;
        }

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated) {
          final user = await repository.getCurrentUser();
          state = AsyncValue.data(user);
        }
      },
    );

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      state = const AsyncValue.data(null);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final user = await repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    await repository.signIn(email, password);
  }

  Future<void> signOut() async {
    await repository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> changePassword(String newPassword) =>
      repository.changePassword(newPassword: newPassword);

  Future<void> resetPassword(String email) =>
      repository.resetPasswordForEmail(email);

  void setUser(UserEntity user) {
    state = AsyncValue.data(user);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}