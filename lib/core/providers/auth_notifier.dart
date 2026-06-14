import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart' as sn;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthStateNotifier2 extends sn.StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository repository;

  StreamSubscription? _authSubscription;

  AuthStateNotifier2(this.repository) : super(const AsyncValue.loading()) {
    _init();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _init() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _handleAuthState,
    );

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      state = const AsyncValue.data(null);
    } else {
      _loadCurrentUser();
    }
  }

  Future<void> _handleAuthState(data) async {
    print("AUTH EVENT: ${data.event}");

    if (data.event == AuthChangeEvent.signedOut || data.session == null) {
      print("USER LOGGED OUT");
      state = const AsyncValue.data(null);
    } else if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.tokenRefreshed ||
        data.event == AuthChangeEvent.userUpdated) {
      print("USER LOGGED IN");
      final user = await repository.getCurrentUser();
      // Solo actualizar el state si encontramos el perfil.
      // Si no hay perfil aún (flujo OAuth en progreso), no tocar el state.
      if (user != null) {
        state = AsyncValue.data(user);
      }
      // Si user == null pero hay sesión activa, el flujo OAuth del LoginPage
      // se encargará de verificar y mostrar el sheet de registro si corresponde.
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await repository.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await repository.signIn(email, password);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Future<void> signInWithGoogle() async {
  //   state = const AsyncValue.loading();
  //   try {
  //     final user = await repository.signInWithGoogle();
  //     state = AsyncValue.data(user);
  //   } catch (e, st) {
  //     state = AsyncValue.error(e, st);
  //   }
  // }

  // Future<void> signInWithFacebook() async {
  //   state = const AsyncValue.loading();
  //   try {
  //     final user = await repository.signInWithFacebook();
  //     state = AsyncValue.data(user);
  //   } catch (e, st) {
  //     state = AsyncValue.error(e, st);
  //   }
  // }

  Future<void> signOut() async {
    try {
      await repository.signOut();
    } catch (e) {
      print("signOut error: $e");
    }
    // Forzar el estado a null para garantizar redirección al login
    // incluso si el stream de onAuthStateChange tarda en disparar
    state = const AsyncValue.data(null);
  }

  Future<void> changePassword({required String newPassword}) async {
    try {
      await repository.changePassword(newPassword: newPassword);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      await repository.resetPasswordForEmail(email);
    } catch (_) {
      rethrow;
    }
  }

  void setUser(UserEntity user) {
    state = AsyncValue.data(user);
  }
}
