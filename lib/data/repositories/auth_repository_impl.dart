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

  @override
  Future<UserEntity?> getCurrentUser() async {
    return datasource.getCurrentUser();
  }

  @override
  Future<void> signOut() async {
    await datasource.signOut();
  }
}

