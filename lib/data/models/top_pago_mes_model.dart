import '../../domain/entities/top_pago_mes.dart';

class TopPagoMesModel extends TopPagoMesEntity {
  const TopPagoMesModel({
    required String idUsuario,
    required String nombreUsuario,
    required double totalPagado,
  }) : super(idUsuario: idUsuario, nombreUsuario: nombreUsuario, totalPagado: totalPagado);

  factory TopPagoMesModel.fromMap(Map<String, dynamic> map) {
    double _numToDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return TopPagoMesModel(
      idUsuario: (map['id_usuario'] ?? map['idUsuario'] ?? '').toString(),
      nombreUsuario: (map['nombre_usuario'] ?? map['nombreUsuario'] ?? '').toString(),
      totalPagado: _numToDouble(map['total_pagado'] ?? map['totalPagado']),
    );
  }
}

