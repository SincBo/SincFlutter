class TopPagoMesEntity {
  final String idUsuario;
  final String nombreUsuario;
  final double totalPagado;

  const TopPagoMesEntity({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.totalPagado,
  });

  Map<String, dynamic> toMap() => {
        'id_usuario': idUsuario,
        'nombre_usuario': nombreUsuario,
        'total_pagado': totalPagado,
      };
}

