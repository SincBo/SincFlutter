class CreatorPorTipoEntity {
  final String idCreador;
  final String idPlan;
  final String nombreCreador;
  final String bio;
  final double precioPlan;
  final String tipoPlan;
  final DateTime fechaInicio;

  CreatorPorTipoEntity({
    required this.idCreador,
    required this.idPlan,
    required this.nombreCreador,
    required this.bio,
    required this.precioPlan,
    required this.tipoPlan,
    required this.fechaInicio,
  });

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

