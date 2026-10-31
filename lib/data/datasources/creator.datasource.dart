import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/creator_model.dart';
import '../models/creator_por_tipo_model.dart';
import '../models/usuario_por_tipo_model.dart';
import '../utils/safe_map.dart';

class CreatorDataSource {
  final SupabaseClient client;

  CreatorDataSource(this.client);

  // =========================
  // OBTENER CREADORES (RPC)
  // =========================
  Future<List<CreatorModel>> obtenerCreadores() async {
    try {
      final res = await client.rpc('obtener_creadores');

      if (res is List) {
        return res.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return CreatorModel.fromMap(map);
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('obtenerCreadores -> error: $e');
      return [];
    }
  }

  // =========================
  // BUSCAR CREADORES
  // =========================
  Future<List<CreatorModel>> buscarCreadores(
      String query, {
        int limit = 50,
        int offset = 0,
      }) async {
    try {
      // No existe una tabla `creadores` (el nombre real es `creador`,
      // singular); el listado público siempre pasa por el RPC
      // `obtener_creadores`, que ya trae planes y publicaciones
      // públicas armados. Filtramos y paginamos del lado del cliente.
      final rpcRes = await client.rpc('obtener_creadores');
      if (rpcRes is! List) return [];

      final all = rpcRes.map((e) => normalizeKeys(mapFromDynamic(e))).toList();

      final q = query.trim().toLowerCase();
      final filtered = q.isEmpty
          ? all
          : all.where((map) {
              final nombre =
                  (map['nombre_usuario'] ?? '').toString().toLowerCase();
              final categoria =
                  (map['categoria'] ?? '').toString().toLowerCase();
              return nombre.contains(q) || categoria.contains(q);
            }).toList();

      return filtered
          .skip(offset)
          .take(limit)
          .map((map) => CreatorModel.fromMap(map))
          .toList();
    } catch (e) {
      debugPrint('buscarCreadores -> error: $e');
      return [];
    }
  }

  // =========================
  // CREADORES POR TIPO (RPC)
  // =========================
  Future<List<CreatorPorTipoModel>> obtenerCreadoresPorTipo(
      String tipoPlan, {
        int limit = 50,
        int offset = 0,
      }) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return [];

      final res = await client.rpc('get_creadores_por_tipo', params: {
        'p_tipo': tipoPlan.trim(),
      });

      if (res is List) {
        return res.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return CreatorPorTipoModel.fromMap(map);
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('obtenerCreadoresPorTipo -> error: $e');
      return [];
    }
  }

  // =========================
  // USUARIOS POR TIPO (SUSCRIPTORES)
  // =========================
  Future<List<UsuarioPorTipoModel>> obtenerUsuarioPorTipo(
      String tipoPlan, {
        int limit = 50,
        int offset = 0,
      }) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return [];

      final res = await client.rpc(
        'get_mis_suscriptores_por_tipo',
        params: {'p_tipo': tipoPlan.trim()},
      );

      if (res is List) {
        return res.map((e) {
          final map = normalizeKeys(mapFromDynamic(e));
          return UsuarioPorTipoModel.fromMap(map);
        }).toList();
      }

      if (res is Map) {
        final map = normalizeKeys(mapFromDynamic(res));
        return [UsuarioPorTipoModel.fromMap(map)];
      }

      return [];
    } catch (e) {
      debugPrint('obtenerUsuarioPorTipo -> error: $e');
      return [];
    }
  }
}