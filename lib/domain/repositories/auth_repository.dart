import '../entities/user.dart';

abstract class AuthRepository {
  /// Sign in with email and password. Returns a [UserEntity] on success or null on failure.
  Future<UserEntity?> signIn(String email, String password);

  /// Sign out current user.
  Future<void> signOut();

  /// Returns the currently signed in user or null.
  Future<UserEntity?> getCurrentUser();
}

