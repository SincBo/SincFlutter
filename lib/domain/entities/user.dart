class UserEntity {
  final String id;
  final String? email;
  final String? username;
  final String? avatarUrl;

  UserEntity({
    required this.id,
    this.email,
    this.username,
    this.avatarUrl,
  });
}

