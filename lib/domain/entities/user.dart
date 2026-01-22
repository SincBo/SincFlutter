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
}

