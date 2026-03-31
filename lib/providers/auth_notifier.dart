import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart' as sn;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';

class AuthStateNotifier extends sn.StateNotifier<AsyncValue<UserEntity?>> {
  final AuthRepository repository;

  StreamSubscription? _authSubscription;

  AuthStateNotifier(this.repository) : super(const AsyncValue.loading()) {
    _init();
  }
  void _init() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      print("AUTH EVENT: ${data.event}");

      if (session == null) {
        print("USER LOGGED OUT");
        state = const AsyncValue.data(null);
      } else {
        print("USER LOGGED IN");
        final user = await repository.getCurrentUser();
        state = AsyncValue.data(user);
      }
    });

    // 🔥 IMPORTANTE: mover esto AL FINAL
    _loadCurrentUser();
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final ds = (repository as dynamic).datasource;

      final profile = await ds.client
          .from('usuario')
          .select()
          .eq('id_usuario', userId)
          .maybeSingle();

      if (profile == null) {
        // Usuario autenticado pero sin perfil
        state = const AsyncValue.data(null);
        return;
      }

      final user = UserEntity.fromMap(profile);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
    } catch (e, st) {
      rethrow;
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      await repository.resetPasswordForEmail(email);
    } catch (e, st) {
      rethrow;
    }
  }

  void setUser(UserEntity user) {
    state = AsyncValue.data(user);
  }
}
