import '../../domain/entities/usuario_por_tipo.dart';

class UsuarioPorTipoModel extends UsuarioPorTipoEntity {
  UsuarioPorTipoModel({
    required String idUsuario,
    required String idPlan,
    required String nombreUsuario,
    required double precioPlan,
    required String tipoPlan,
    required DateTime fechaInicio,
  }) : super(
    idUsuario: idUsuario,
    idPlan: idPlan,
    nombreUsuario: nombreUsuario,
    precioPlan: precioPlan,
    tipoPlan: tipoPlan,
    fechaInicio: fechaInicio,
        );

  factory UsuarioPorTipoModel.fromMap(Map<String, dynamic> map) {
    final fecha = map['fecha_inicio'];
    DateTime fechaInicio;
    if (fecha is String) {
      fechaInicio = DateTime.tryParse(fecha) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (fecha is DateTime) {
      fechaInicio = fecha;
    } else {
      fechaInicio = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return UsuarioPorTipoModel(
      idUsuario: map['id_usuario'] as String? ?? '',
      idPlan: map['id_plan'] as String? ?? '',
      nombreUsuario: map['nombre_usuario'] as String? ?? '',
      precioPlan: (map['precio_plan'] is num) ? (map['precio_plan'] as num).toDouble() : 0.0,
      tipoPlan: map['tipo_plan'] as String? ?? '',
      fechaInicio: fechaInicio,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'id_plan': idPlan,
      'nombre_usuario': nombreUsuario,
      'precio_plan': precioPlan,
      'tipo_plan': tipoPlan,
      'fecha_inicio': fechaInicio.toIso8601String(),
    };
  }
}

