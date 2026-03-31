class UserEntity {
  final String id;
  final String? email;
  final String? username;
  final String? avatarUrl;
  final bool esCreador;

  UserEntity({
    required this.id,
    this.email,
    this.username,
    this.avatarUrl,
    required this.esCreador,
  });

  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      id: map['id_usuario'] as String,
      email: map['email'] as String?,
      username: map['nombre_usuario'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      esCreador: map['es_creador'] ?? false,
    );
  }
}

