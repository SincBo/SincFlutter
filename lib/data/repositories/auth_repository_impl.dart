import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseDataSource datasource;

  AuthRepositoryImpl(this.datasource);

  @override
  Future<UserEntity?> signIn(String email, String password) async {
    return await datasource.signInWithEmail(email, password);
  }

  // @override
  // Future<UserEntity?> signInWithGoogle() async {
  //   final user = await datasource.signInWithFacebook();
  //
  //   if (user == null) return null;
  //
  //   return UserEntity(
  //     id: user.id,
  //     email: user.email ?? '',
  //   );
  // }
  //
  // @override
  // Future<UserEntity?> signInWithFacebook() async {
  //   final user = await datasource.signInWithGoogle();
  //
  //   if (user == null) return null;
  //
  //   return UserEntity(
  //     id: user.id,
  //     email: user.email ?? '',
  //   );
  // }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return datasource.getCurrentUser();
  }

  @override
  Future<void> signOut() async {
    await datasource.signOut();
  }

  @override
  Future<void> changePassword({required String newPassword}) async {
    await datasource.changePassword(newPassword: newPassword);
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    await datasource.resetPasswordForEmail(email);
  }
}

