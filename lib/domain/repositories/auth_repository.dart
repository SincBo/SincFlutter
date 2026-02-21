import '../entities/user.dart';

abstract class AuthRepository {
  /// Sign in with email and password. Returns a [UserEntity] on success or null on failure.
  Future<UserEntity?> signIn(String email, String password);

  /// Sign in with Google OAuth. Returns a [UserEntity] on success or null on failure.
  Future<UserEntity?> signInWithGoogle();

  /// Sign in with Facebook OAuth. Returns a [UserEntity] on success or null on failure.
  Future<UserEntity?> signInWithFacebook();

  /// Sign out current user.
  Future<void> signOut();

  /// Change password for current user.
  Future<void> changePassword({required String newPassword});

  /// Send password reset email.
  Future<void> resetPasswordForEmail(String email);

  /// Returns the currently signed in user or null.
  Future<UserEntity?> getCurrentUser();
}

