import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ganancias_mes_model.dart';
import '../models/top_pago_mes_model.dart';
import '../utils/safe_map.dart';

class AnalyticsDataSource {
  final SupabaseClient client;

  AnalyticsDataSource(this.client);

  Future<List<Map<String, dynamic>>> obtenerGananciasCreadorMes({
    required String creadorId,
    required int year,
    required int month,
  }) async {
    try {
      final res = await client.rpc(
        'get_ganancias_creador_mes_v1',
        params: {
          'p_id_creador': creadorId,
          'p_year': year,
          'p_month': month,
        },
      );

      if (res == null) return [];

      List<Map<String, dynamic>> toList(dynamic value) {
        if (value is List) {
          return value
              .map((e) => normalizeKeys(mapFromDynamic(e)))
              .toList();
        }

        if (value is Map) {
          return [normalizeKeys(mapFromDynamic(value))];
        }

        return [];
      }

      final list = toList(res);

      return list.map((m) {
        return {
          'anio': m['anio'] ?? m['year'] ?? year,
          'mes': m['mes'] ?? m['month'] ?? month,
          'total_bruto': (m['total_bruto'] ?? 0),
          'fee': (m['fee'] ?? 0),
          'balance': (m['balance'] ?? 0),
          'comunidad_monto': (m['comunidad_monto'] ?? 0),
          'comunidad_suscriptores': (m['comunidad_suscriptores'] ?? 0),
          'fellow_monto': (m['fellow_monto'] ?? 0),
          'tips_monto': (m['tips_monto'] ?? 0),
          'contenido_solicitado_monto':
          (m['contenido_solicitado_monto'] ?? 0),
        };
      }).toList();
    } catch (e) {
      debugPrint('obtenerGananciasCreadorMes -> error: $e');
      return [];
    }
  }

  Future<List<GananciasMesModel>> obtenerGananciasCreadorMesModel({
    required String creadorId,
    required int year,
    required int month,
  }) async {
    try {
      final res = await client.rpc(
        'get_ganancias_creador_mes_v1',
        params: {
          'p_id_creador': creadorId,
          'p_year': year,
          'p_month': month,
        },
      );

      if (res == null) return [];

      final list = (res is List)
          ? res
          : (res is Map)
          ? [res]
          : [];

      return list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return GananciasMesModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('obtenerGananciasCreadorMesModel -> error: $e');
      return [];
    }
  }

  Future<List<TopPagoMesModel>> obtenerTopPagosCreadorMes({
    required String creadorId,
    required int year,
    required int month,
    int limit = 10,
  }) async {
    try {
      final res = await client.rpc(
        'get_top_pagos_creador_mes_v1',
        params: {
          'p_id_creador': creadorId,
          'p_year': year,
          'p_month': month,
          'p_limit': limit,
        },
      );

      if (res == null) return [];

      final list = (res is List)
          ? res
          : (res is Map)
          ? [res]
          : [];

      return list.map((e) {
        final map = normalizeKeys(mapFromDynamic(e));
        return TopPagoMesModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('obtenerTopPagosCreadorMes -> error: $e');
      return [];
    }
  }
}