import '../entities/user.dart';

abstract class AuthRepository {
  /// Sign in with email and password. Returns a [UserEntity] on success or null.
  Future<UserEntity?> signIn(String email, String password);

  /// Sign in with Google OAuth. Returns a [UserEntity] on success or null.
  Future<UserEntity?> signInGoogle();

  /// Sign in nativo con Apple (solo iOS). Returns a [UserEntity] on success or null.
  Future<UserEntity?> signInApple();

  // Future<UserEntity?> signInWithFacebook();

  /// Sign out current user.
  Future<void> signOut();

  /// Borra permanentemente la cuenta del usuario actual y todos sus datos.
  Future<void> deleteAccount();

  /// Change password for current user.
  Future<void> changePassword({required String newPassword});

  /// Send password reset email.
  Future<void> resetPasswordForEmail(String email);

  /// Returns the currently signed in user or null.
  Future<UserEntity?> getCurrentUser();

  Future<void> insertUser(String nameUser, String email, bool isCreator);
  Future<void> updateUser(String telefono, String codigoInv);
  Future<Map<String, dynamic>?> getExistingProfile();

  Future<UserEntity?> signUpWithEmail({
    required String email,
    required String password,
    required String nombreUsuario,
    bool esCreador = false,
  });

  /// Returns true if there is an active Supabase session (user is authenticated),
  /// regardless of whether they have a profile in the usuario table.
  Future<bool> isAuthenticated();

  /// Returns basic auth info (email, displayName) from the active session.
  /// Useful for pre-filling sign-up forms after OAuth. Returns null if no session.
  Future<({String? email, String? displayName})?> getAuthUserInfo();

}

