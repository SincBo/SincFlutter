class CreatorEntity {
  final String idUsuario;
  final String nombreUsuario;
  final String email;
  final String bio;
  final double precioSuscripcion;
  final double precioSuscripcionFellow;
  final String? categoria;
  final List<dynamic>? publicaciones;

  CreatorEntity({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.email,
    required this.bio,
    required this.precioSuscripcion,
    required this.precioSuscripcionFellow,
    this.categoria,
    this.publicaciones,
  });

  /// Convert the entity to a Map using the same keys as CreatorModel.toMap
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre_usuario': nombreUsuario,
      'email': email,
      'bio': bio,
      'precio_suscripcion': precioSuscripcion,
      'precio_suscripcion_fellow': precioSuscripcionFellow,
      'categoria': categoria,
      'publicaciones': publicaciones,
    };
  }
}
