import '../../domain/entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel extends UserEntity {
  UserModel({required String id, String? email, String? username, String? avatarUrl, required bool esCreador,}) : super(id: id, email: email, username: username, avatarUrl: avatarUrl, esCreador: esCreador);

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      esCreador: map['es_creador'] as bool? ?? false,
    );
  }

  factory UserModel.fromUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
      esCreador: false, // placeholder
    );
  }

  factory UserModel.fromAuthAndProfile(User user, Map<String, dynamic> profile) {
    final meta = user.userMetadata ?? {};
    return UserModel(
      id: user.id,
      email: user.email,
      username: profile['nombre_usuario'] as String?,
      esCreador: profile['es_creador'] as bool? ?? false,
      avatarUrl: meta['avatar_url'] as String?, // 👈 viene de Auth
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar_url': avatarUrl,
    };
  }
}

