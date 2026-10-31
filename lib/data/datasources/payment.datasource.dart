import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Datasource de pagos. Reemplaza al `paymente.datasource.dart` que se
/// borró en el commit "new refactor app sinc" sin dejar reemplazo, lo
/// cual dejaba roto todo el módulo de `PaymentRepository`/`PaymentDataSource`
/// (incluyendo el botón real de "Suscribirse" en creator_profile.page.dart).
///
/// El monto de la suscripción YA NO se manda desde el cliente: el precio
/// real se calcula del lado servidor dentro del RPC `create_transaction`
/// (a partir de `plan_suscripcion.precio`), como parte del fix de
/// seguridad que valida el monto contra el plan real.
class PaymentDataSource {
  final SupabaseClient client;

  PaymentDataSource(this.client);

  /// Crea la transacción pendiente llamando al RPC `create_transaction`.
  /// Devuelve el `id_transaccion` como String, o null si falla.
  Future<String?> createTransaction({
    required String creatorId,
    required String planId,
  }) async {
    try {
      final res = await client.rpc('create_transaction', params: {
        'p_id_creador': creatorId,
        'p_id_plan': planId,
      });

      if (res == null) return null;
      if (res is Map) {
        final id = res['id_transaccion'];
        return id?.toString();
      }
      return res.toString();
    } catch (e) {
      debugPrint('PaymentDataSource.createTransaction -> error: $e');
      return null;
    }
  }

  /// Genera el QR de pago invocando la Edge Function `vpay-generate-qr`.
  /// Esa función lee el monto real desde la transacción ya creada en la
  /// base de datos, no confía en nada que mande el cliente.
  Future<dynamic> generateQr({required String transactionId}) async {
    final resp = await client.functions.invoke(
      'vpay-generate-qr',
      body: {'id_transaccion': transactionId},
    );
    try {
      return resp.data;
    } catch (_) {
      return resp;
    }
  }

  /// Consulta el estado de un QR ya generado invocando `vpay-get-qr`.
  Future<dynamic> getQrById(String id) async {
    final resp = await client.functions.invoke(
      'vpay-get-qr',
      body: {'id': id},
    );
    try {
      return resp.data;
    } catch (_) {
      return resp;
    }
  }

  /// Verifica si el usuario autenticado está suscrito a un plan concreto.
  Future<bool> esSuscriptorDePlan(String idPlan) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return false;

      // Antes esto consultaba la tabla `suscripcion` directo y no
      // miraba `fecha_fin` (una suscripción vencida contaba como
      // activa). El RPC sí valida vigencia, igual que
      // get_or_create_chat_por_plan.
      final res = await client.rpc('esta_suscrito_a_plan', params: {
        'p_id_plan': idPlan,
      });

      if (res is bool) return res;
      if (res is List && res.isNotEmpty && res.first is bool) {
        return res.first as bool;
      }
      return false;
    } catch (e) {
      debugPrint('PaymentDataSource.esSuscriptorDePlan -> error: $e');
      return false;
    }
  }

  /// Verifica si el usuario autenticado está suscrito a un creador,
  /// vía el RPC `esta_suscrito`.
  Future<bool> estaSuscrito(String idCreador) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return false;

      final rpcRes = await client.rpc('esta_suscrito', params: {
        'p_id_usuario': user.id,
        'p_id_creador': idCreador,
      });

      if (rpcRes == null) return false;
      if (rpcRes is bool) return rpcRes;
      if (rpcRes is List && rpcRes.isNotEmpty) {
        final first = rpcRes.first;
        if (first is bool) return first;
      }
      return false;
    } catch (e) {
      debugPrint('PaymentDataSource.estaSuscrito -> error: $e');
      return false;
    }
  }
}
