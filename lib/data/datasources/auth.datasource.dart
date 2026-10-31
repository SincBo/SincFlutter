import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../models/user_model.dart';

// Client IDs de Google Cloud Console (proyecto usado por el proveedor de
// Google en Supabase). El web client ID es el mismo que ya está configurado
// en Supabase Dashboard -> Authentication -> Providers -> Google.
const String _googleWebClientId =
    '215940025127-e9etpknh5rfe8p7jd03ifom9mak2t76u.apps.googleusercontent.com';
const String _googleIosClientId =
    '215940025127-e6btmotii3mu2hnoi4rvap35fvoqd9kv.apps.googleusercontent.com';

class AuthDataSource {
  final SupabaseClient client;
  bool _googleSignInInitialized = false;

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

  /// Borra la cuenta del usuario actual de forma permanente.
  /// Requiere la Edge Function `delete-account` (service role), ya que el
  /// cliente no tiene permisos para borrar de auth.users directamente.
  /// Exigido por Apple Guideline 5.1.1(v): las apps con registro de cuenta
  /// deben ofrecer borrado de cuenta real (no solo desactivación).
  Future<void> deleteAccount() async {
    try {
      final res = await client.functions.invoke('delete-account');
      if (res.status != 200) {
        final data = res.data;
        final serverMessage = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'status ${res.status}';
        throw Exception(serverMessage);
      }
      await client.auth.signOut();
    } catch (e) {
      debugPrint('deleteAccount -> error: $e');
      rethrow;
    }
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
    // En iOS usamos el selector nativo de Google (sin navegador). El flujo
    // basado en navegador (signInWithOAuth + SFSafariViewController) falla
    // de forma recurrente en iOS con PlatformException("Error while
    // launching...") tanto en Simulador como en dispositivo real; Supabase
    // mismo recomienda el flujo nativo para iOS por esto.
    // En Android dejamos el flujo existente porque ahí sí funciona bien.
    if (Platform.isIOS) {
      return _signInWithGoogleNative();
    }
    return _signInWithOAuthProvider(
      OAuthProvider.google,
      'signInWithGoogle',
    );
  }

  Future<User?> _signInWithGoogleNative() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      if (!_googleSignInInitialized) {
        await googleSignIn.initialize(
          serverClientId: _googleWebClientId,
          clientId: _googleIosClientId,
        );
        _googleSignInInitialized = true;
      }

      final googleUser = await googleSignIn.authenticate();

      const scopes = ['email', 'profile'];
      final authorization = await googleUser.authorizationClient
              .authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw Exception('No se obtuvo idToken de Google.');
      }

      final res = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );

      final user = res.user;
      if (user != null) {
        await _ensureUserProfile(
          userId: user.id,
          email: googleUser.email,
          nombreUsuario: googleUser.displayName ?? '',
        );
      }

      return user;
    } catch (e) {
      debugPrint('signInWithGoogle (native iOS) -> error: $e');
      rethrow;
    }
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

      final user = res.user;
      if (user != null) {
        final nombreApple = [credential.givenName, credential.familyName]
            .where((s) => s != null && s.trim().isNotEmpty)
            .join(' ')
            .trim();
        await _ensureUserProfile(
          userId: user.id,
          email: credential.email ?? user.email ?? '',
          nombreUsuario: nombreApple,
        );
      }

      return user;
    } catch (e) {
      debugPrint('signInWithApple -> error: $e');
      rethrow;
    }
  }

  /// Crea el perfil en `usuario` automáticamente si todavía no existe,
  /// usando lo que el proveedor (Apple/Google) ya nos entregó.
  ///
  /// Apple exige (Guideline 4 / HIG de Sign in with Apple) que la app NO le
  /// vuelva a pedir al usuario datos que Authentication Services ya nos dio
  /// (nombre, correo). Por eso el login social ya no muestra ningún
  /// formulario bloqueante pidiendo nombre/apellido/correo: creamos el
  /// perfil solos, con lo disponible, y si Apple no compartió el nombre
  /// (pasa seguido a partir del segundo login) usamos un valor por defecto
  /// que el usuario puede cambiar después desde su perfil.
  Future<void> _ensureUserProfile({
    required String userId,
    required String email,
    required String nombreUsuario,
  }) async {
    try {
      final existing = await client
          .from('usuario')
          .select('id_usuario')
          .eq('id_usuario', userId)
          .maybeSingle();
      if (existing != null) return;

      final fallbackNombre = nombreUsuario.trim().isNotEmpty
          ? nombreUsuario.trim()
          : (email.contains('@') ? email.split('@').first : 'Usuario');

      await client.from('usuario').insert({
        'id_usuario': userId,
        'nombre_usuario': fallbackNombre,
        'email': email,
        'es_creador': false,
      });
    } catch (e) {
      // No bloqueamos el login si esto falla (ej. condición de carrera con
      // otro insert, o el correo ya pertenece a otra cuenta): getCurrentUser()
      // decide después si hay perfil disponible o no.
      debugPrint('_ensureUserProfile -> error: $e');
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
        // inAppWebView abre el login dentro de la app (SFSafariViewController
        // en iOS / Chrome Custom Tab en Android) en vez de mandar al usuario
        // a la app de Safari. Apple lo exige explícitamente (Guideline 4):
        // sacar al usuario al navegador externo cuenta como mala UX.
        authScreenLaunchMode: LaunchMode.inAppWebView,
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