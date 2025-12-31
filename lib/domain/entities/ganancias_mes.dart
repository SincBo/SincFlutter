class GananciasMesEntity {
  final int anio;
  final int mes;
  final double totalBruto;
  final double fee;
  final double balance;
  final double comunidadMonto;
  final int comunidadSuscriptores;
  final double fellowMonto;
  final double tipsMonto;
  final double contenidoSolicitadoMonto;

  const GananciasMesEntity({
    required this.anio,
    required this.mes,
    required this.totalBruto,
    required this.fee,
    required this.balance,
    required this.comunidadMonto,
    required this.comunidadSuscriptores,
    required this.fellowMonto,
    required this.tipsMonto,
    required this.contenidoSolicitadoMonto,
  });

  Map<String, dynamic> toMap() => {
        'anio': anio,
        'mes': mes,
        'total_bruto': totalBruto,
        'fee': fee,
        'balance': balance,
        'comunidad_monto': comunidadMonto,
        'comunidad_suscriptores': comunidadSuscriptores,
        'fellow_monto': fellowMonto,
        'tips_monto': tipsMonto,
        'contenido_solicitado_monto': contenidoSolicitadoMonto,
      };
}

