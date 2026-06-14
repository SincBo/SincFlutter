import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class AuthDataSource {
  final SupabaseClient client;

  AuthDataSource(this.client);

  Future<UserModel?> signInWithEmail(
      String email,
      String password,
      ) async {
    try {
      final res = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user == null) {
        return null;
      }

      final profile = await client
          .from('usuario')
          .select(
        'id_usuario, email, nombre_usuario, es_creador',
      )
          .eq('id_usuario', user.id)
          .maybeSingle();

      if (profile != null) {
        return UserModel.fromAuthAndProfile(
          user,
          profile,
        );
      }

      return UserModel.fromUser(user);
    } catch (e) {
      debugPrint(
        'signInWithEmail -> error: $e',
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> changePassword({
    required String newPassword,
  }) async {
    try {
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'No hay usuario autenticado',
        );
      }

      final response = await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (response.user == null) {
        throw Exception(
          'No se pudo actualizar la contraseña',
        );
      }
    } catch (e) {
      debugPrint(
        'changePassword -> error: $e',
      );
      rethrow;
    }
  }

  Future<void> resetPasswordForEmail(
      String email,
      ) async {
    try {
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo:
        'com.sincbo.sincboflutter://login-callback',
      );
    } catch (e) {
      debugPrint(
        'resetPasswordForEmail -> error: $e',
      );
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;

      if (user == null) {
        return null;
      }

      final profile = await client
          .from('usuario')
          .select(
        'id_usuario, email, nombre_usuario, es_creador',
      )
          .eq('id_usuario', user.id)
          .maybeSingle();

      if (profile == null) {
        return null;
      }

      return UserModel.fromAuthAndProfile(
        user,
        profile,
      );
    } catch (e, st) {
      debugPrint(
        'getCurrentUser -> error: $e\n$st',
      );
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    return _signInWithOAuthProvider(
      OAuthProvider.google,
      'signInWithGoogle',
    );
  }

  Future<User?> signInWithFacebook() async {
    return _signInWithOAuthProvider(
      OAuthProvider.facebook,
      'signInWithFacebook',
    );
  }

  Future<User?> _signInWithOAuthProvider(
      OAuthProvider provider,
      String providerName,
      ) async {
    try {
      final completer = Completer<User?>();

      StreamSubscription? subscription;

      subscription =
          client.auth.onAuthStateChange.listen(
                (data) {
              if (data.event ==
                  AuthChangeEvent.signedIn &&
                  data.session?.user != null &&
                  !completer.isCompleted) {
                completer.complete(
                  data.session!.user,
                );
              }
            },
          );

      final started =
      await client.auth.signInWithOAuth(
        provider,
        redirectTo:
        'com.sincbo.sincboflutter://login-callback',
      );

      if (!started) {
        await subscription.cancel();
        return null;
      }

      final user = await completer.future.timeout(
        const Duration(
          seconds: 60,
        ),
        onTimeout: () =>
        client.auth.currentUser,
      );

      await subscription.cancel();

      return user;
    } catch (e) {
      debugPrint(
        '$providerName -> error: $e',
      );
      rethrow;
    }
  }

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String nombreUsuario,
    bool esCreador = false,
  }) async {
    try {
      final signUpRes =
      await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre_usuario':
          nombreUsuario,
          'es_creador':
          esCreador,
        },
      );

      final user = signUpRes.user;

      if (user == null) {
        return null;
      }

      try {
        await client.from('usuario').insert({
          'id_usuario': user.id,
          'nombre_usuario':
          nombreUsuario,
          'email': email,
          'es_creador':
          esCreador,
        });
      } catch (e) {
        debugPrint(
          'signUpWithEmail -> insert Usuario error: $e',
        );
      }

      return UserModel.fromUser(user);
    } catch (e) {
      debugPrint(
        'signUpWithEmail -> error: $e',
      );
      rethrow;
    }
  }
}