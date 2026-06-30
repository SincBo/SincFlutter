import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class AuthDataSource {
  final SupabaseClient client;

  AuthDataSource(this.client);

  /// Returns true if there is an active session.
  Future<bool> isAuthenticated() async {
    return client.auth.currentSession != null;
  }

  /// Returns email and displayName from the active session metadata.
  Future<({String? email, String? displayName})?> getAuthUserInfo() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final fullName = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String?;
    return (email: user.email, displayName: fullName);
  }

  Future<void> insertUser(String nameUser, String email, bool isCreator) async {
    final currentUser = client.auth.currentUser;
    await client.from('usuario').insert({
      'id_usuario': currentUser?.id,
      'nombre_usuario': nameUser,
      'email': email,
      'es_creador': isCreator,
    });
  }

  Future<Map<String, dynamic>?> getExistingProfile() async {
    final currentUser = client.auth.currentUser;
    final profile = await client
        .from('usuario').select()
        .eq('id_usuario', currentUser!.id)
    .maybeSingle();
    return profile;
  }

  Future<void> updateUser(String telefono, String codigoInv) async {
    final currentUser = client.auth.currentUser;
    await client.from('usuario').update({
      'telefono': telefono.isNotEmpty ? telefono : null,
      'codigo_inv': codigoInv.isNotEmpty ? codigoInv : null,
    }).eq('id_usuario', currentUser!.id);
  }

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

  /// Sign in nativo con Apple usando idToken + nonce.
  /// Apple exige este flujo (no browser) para apps en el App Store.
  Future<User?> signInWithApple() async {
    try {
      // 1. Generar nonce aleatorio y su hash SHA-256
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      // 2. Solicitar credencial de Apple con el nonce hasheado
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple no retornó un identity token');
      }

      // 3. Intercambiar el idToken con Supabase (enviamos el nonce sin hashear)
      final res = await client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      return res.user;
    } catch (e) {
      debugPrint('signInWithApple -> error: $e');
      rethrow;
    }
  }

  // ── helpers para el nonce ──────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Future<User?> signInWithFacebook() async {
  //   return _signInWithOAuthProvider(
  //     OAuthProvider.facebook,
  //     'signInWithFacebook',
  //   );
  // }

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
        redirectTo: 'com.sincbo.sincboflutter://login-callback',
      );

      if (!started) {
        await subscription.cancel();
        return null;
      }

      final user = await completer.future.timeout(
        const Duration(
          seconds: 60,
        ),
        onTimeout: () => client.auth.currentUser,
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