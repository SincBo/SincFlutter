import '../../domain/entities/ganancias_mes.dart';

class GananciasMesModel extends GananciasMesEntity {
  const GananciasMesModel({
    required int anio,
    required int mes,
    required double totalBruto,
    required double fee,
    required double balance,
    required double comunidadMonto,
    required int comunidadSuscriptores,
    required double fellowMonto,
    required double tipsMonto,
    required double contenidoSolicitadoMonto,
  }) : super(
          anio: anio,
          mes: mes,
          totalBruto: totalBruto,
          fee: fee,
          balance: balance,
          comunidadMonto: comunidadMonto,
          comunidadSuscriptores: comunidadSuscriptores,
          fellowMonto: fellowMonto,
          tipsMonto: tipsMonto,
          contenidoSolicitadoMonto: contenidoSolicitadoMonto,
        );

  factory GananciasMesModel.fromMap(Map<String, dynamic> map) {
    double _numToDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int _numToInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return GananciasMesModel(
      anio: _numToInt(map['anio'] ?? map['year']),
      mes: _numToInt(map['mes'] ?? map['month']),
      totalBruto: _numToDouble(map['total_bruto'] ?? map['subtotal']),
      fee: _numToDouble(map['fee'] ?? map['founders_fee']),
      balance: _numToDouble(map['balance']),
      comunidadMonto: _numToDouble(map['comunidad_monto']),
      comunidadSuscriptores: _numToInt(map['comunidad_suscriptores']),
      fellowMonto: _numToDouble(map['fellow_monto']),
      tipsMonto: _numToDouble(map['tips_monto']),
      contenidoSolicitadoMonto: _numToDouble(map['contenido_solicitado_monto']),
    );
  }
}

