class UsuarioPorTipoEntity {
  final String idUsuario;
  final String idPlan;
  final String nombreUsuario;
  final double precioPlan;
  final String tipoPlan;
  final DateTime fechaInicio;

  UsuarioPorTipoEntity({
    required this.idUsuario,
    required this.idPlan,
    required this.nombreUsuario,
    required this.precioPlan,
    required this.tipoPlan,
    required this.fechaInicio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_creador': idUsuario,
      'id_plan': idPlan,
      'nombre_creador': nombreUsuario,
      'precio_plan': precioPlan,
      'tipo_plan': tipoPlan,
      'fecha_inicio': fechaInicio.toIso8601String(),
    };
  }
}

