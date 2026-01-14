import '../../domain/entities/creator_por_tipo.dart';

class CreatorPorTipoModel extends CreatorPorTipoEntity {
  CreatorPorTipoModel({
    required String idCreador,
    required String idPlan,
    required String nombreCreador,
    required String bio,
    required double precioPlan,
    required String tipoPlan,
    required DateTime fechaInicio,
  }) : super(
          idCreador: idCreador,
          idPlan: idPlan,
          nombreCreador: nombreCreador,
          bio: bio,
          precioPlan: precioPlan,
          tipoPlan: tipoPlan,
          fechaInicio: fechaInicio,
        );

  factory CreatorPorTipoModel.fromMap(Map<String, dynamic> map) {
    final fecha = map['fecha_inicio'];
    DateTime fechaInicio;
    if (fecha is String) {
      fechaInicio = DateTime.tryParse(fecha) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (fecha is DateTime) {
      fechaInicio = fecha;
    } else {
      fechaInicio = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return CreatorPorTipoModel(
      idCreador: map['id_creador'] as String? ?? '',
      idPlan: map['id_plan'] as String? ?? '',
      nombreCreador: map['nombre_creador'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      precioPlan: (map['precio_plan'] is num) ? (map['precio_plan'] as num).toDouble() : 0.0,
      tipoPlan: map['tipo_plan'] as String? ?? '',
      fechaInicio: fechaInicio,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id_creador': idCreador,
      'id_plan': idPlan,
      'nombre_creador': nombreCreador,
      'bio': bio,
      'precio_plan': precioPlan,
      'tipo_plan': tipoPlan,
      'fecha_inicio': fechaInicio.toIso8601String(),
    };
  }
}

