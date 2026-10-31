import 'package:sincboflutter/data/datasources/auth.datasource.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource datasource;

  AuthRepositoryImpl(this.datasource);

  @override
  Future<UserEntity?> signIn(String email, String password) {
    return datasource.signInWithEmail(email, password);
  }

  @override
  Future<UserEntity?> getCurrentUser() {
    return datasource.getCurrentUser();
  }

  @override
  Future<void> signOut() {
    return datasource.signOut();
  }

  @override
  Future<void> deleteAccount() {
    return datasource.deleteAccount();
  }

  @override
  Future<void> changePassword({required String newPassword}) {
    return datasource.changePassword(newPassword: newPassword);
  }

  @override
  Future<void> resetPasswordForEmail(String email) {
    return datasource.resetPasswordForEmail(email);
  }

  /// Google sign-in: el datasource maneja el OAuth y luego
  /// obtenemos el perfil completo para retornar un [UserEntity].
  @override
  Future<UserEntity?> signInGoogle() async {
    final user = await datasource.signInWithGoogle();
    if (user == null) return null;
    return datasource.getCurrentUser();
  }

  /// Apple sign-in: idToken nativo → Supabase → perfil completo.
  @override
  Future<UserEntity?> signInApple() async {
    final user = await datasource.signInWithApple();
    if (user == null) return null;
    return datasource.getCurrentUser();
  }

  @override
  Future<void> insertUser(String nameUser, String email, bool isCreator) {
    return datasource.insertUser(nameUser, email, isCreator);
  }

  @override
  Future<void> updateUser(String telefono, String codigoInv) {
    return datasource.updateUser(telefono, codigoInv);
  }

  @override
  Future<Map<String, dynamic>?> getExistingProfile() {
    return datasource.getExistingProfile();
  }

  @override
  Future<UserEntity?> signUpWithEmail({
    required String email,
    required String password,
    required String nombreUsuario,
    bool esCreador = false,
  }) {
    return datasource.signUpWithEmail(
      email: email,
      password: password,
      nombreUsuario: nombreUsuario,
      esCreador: esCreador,
    );
  }

  @override
  Future<bool> isAuthenticated() {
    return datasource.isAuthenticated();
  }

  @override
  Future<({String? email, String? displayName})?> getAuthUserInfo() {
    return datasource.getAuthUserInfo();
  }
}

