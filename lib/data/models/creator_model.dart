import '../../domain/entities/creator.dart';

class CreatorModel extends CreatorEntity {
  CreatorModel({
    required String idUsuario,
    required String nombreUsuario,
    required String email,
    required String bio,
    required double precioSuscripcion,
    required double precioSuscripcionFellow,
    String? categoria,
    List<dynamic>? publicaciones,
  }) : super(
          idUsuario: idUsuario,
          nombreUsuario: nombreUsuario,
          email: email,
          bio: bio,
          precioSuscripcion: precioSuscripcion,
          precioSuscripcionFellow: precioSuscripcionFellow,
          categoria: categoria,
          publicaciones: publicaciones,
        );

  factory CreatorModel.fromMap(Map<String, dynamic> map) {
    return CreatorModel(
      idUsuario: map['id_usuario'] as String? ?? '',
      nombreUsuario: map['nombre_usuario'] as String? ?? '',
      email: map['email'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      precioSuscripcion: (map['precio_suscripcion'] is num) ? (map['precio_suscripcion'] as num).toDouble() : 0.0,
      precioSuscripcionFellow: (map['precio_suscripcion_fellow'] is num) ? (map['precio_suscripcion_fellow'] as num).toDouble() : 0.0,
      categoria: map['categoria'] as String?,
      publicaciones: map['publicaciones'] as List<dynamic>?,
    );
  }

  @override
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
