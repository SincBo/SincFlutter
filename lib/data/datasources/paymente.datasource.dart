import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentDataSource {
  final SupabaseClient client;

  PaymentDataSource(this.client);

  // =========================
  // CREATE TRANSACTION
  // =========================
  Future<String?> createTransaction({
    required String creatorId,
    required String planId,
    required double price,
  }) async {
    String? _parseId(dynamic res) {
      if (res == null) return null;
      if (res is String && res.isNotEmpty) return res;
      if (res is num) return res.toString();

      if (res is List && res.isNotEmpty) {
        return _parseId(res.first);
      }

      if (res is Map) {
        final keys = [
          'id_transaccion',
          'idTransaccion',
          'transaction_id',
          'transactionId',
        ];

        for (final k in keys) {
          final v = _parseId(res[k]);
          if (v != null) return v;
        }

        for (final v in res.values) {
          final parsed = _parseId(v);
          if (parsed != null) return parsed;
        }
      }

      return null;
    }

    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final planTipo = planId.toLowerCase().contains('fellow')
          ? 'Fellow'
          : planId.toLowerCase().contains('comunidad')
          ? 'Comunidad'
          : planId;

      final attempts = [
        {
          'p_id_creador': creatorId,
          'p_id_plan': planId,
          'p_monto': price,
        },
        {
          'p_id_creador': creatorId,
          'p_tipo': planTipo,
          'p_monto': price,
        },
      ];

      for (final params in attempts) {
        try {
          final res = await client.rpc('create_transaction', params: params);
          final id = _parseId(res);
          if (id != null) return id;
        } catch (_) {}
      }

      return null;
    } catch (e) {
      debugPrint('createTransaction -> error: $e');
      return null;
    }
  }

  // =========================
  // GENERATE QR (VPay)
  // =========================
  Future<dynamic> generateQr({
    required double amount,
    required String gloss,
    String? additionalData,
    required String destinationAccountId,
    String? callbackUrl,
    String? transactionIdentifier,
  }) async {
    try {
      var dest = destinationAccountId;

      final uuidLike = RegExp(r'^[0-9a-fA-F]{8}-');
      if (uuidLike.hasMatch(dest)) {
        dest = '3332CO';
      }

      final expirationDate = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;

      final txId = transactionIdentifier ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final payload = {
        'operation': 'VTO041',
        'header': [
          {'attribute': 'currency', 'value': 'BOB'},
          {'attribute': 'gloss', 'value': gloss},
          {'attribute': 'amount', 'value': amount.toString()},
          {'attribute': 'expirationDate', 'value': expirationDate},
          {'attribute': 'additionalData', 'value': additionalData ?? gloss},
          {'attribute': 'destinationAccountId', 'value': dest},
          {'attribute': 'transactionIdentifier', 'value': txId},
          {'attribute': 'user', 'value': 'testVpay'},
          {'attribute': 'company', 'value': '303'},
          {'attribute': 'originCollection', 'value': 'PWEB/APPM'},
          if (callbackUrl != null)
            {'attribute': 'callback', 'value': callbackUrl},
        ],
        'detail': [
          {
            'items': [
              {'attribute': 'YGN-RUTA1', 'value': '2'}
            ]
          }
        ],
      };

      Future<dynamic> call(dynamic body) async {
        return await client.functions.invoke(
          'vpay-generate-qr',
          body: body,
        );
      }

      dynamic response;

      try {
        response = await call(payload);
      } catch (e) {
        try {
          response = await call(jsonEncode(payload));
        } catch (_) {
          return {'ok': false, 'error': e.toString()};
        }
      }

      final data = response.data ?? response;

      String? extract(dynamic v) {
        if (v is String && v.length > 100) {
          return 'data:image/png;base64,$v';
        }
        if (v is Map) {
          for (final e in v.values) {
            final r = extract(e);
            if (r != null) return r;
          }
        }
        if (v is List) {
          for (final e in v) {
            final r = extract(e);
            if (r != null) return r;
          }
        }
        return null;
      }

      if (data is Map && data.containsKey('responseList')) {
        final qr = extract(data['responseList']);
        if (qr != null) return qr;
      }

      return data;
    } catch (e) {
      debugPrint('generateQr -> error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  // =========================
  // GET QR BY ID
  // =========================
  Future<dynamic> getQrById(String id) async {
    try {
      final payload = {'id': id};

      final res = await client.functions.invoke(
        'vpay-get-qr',
        body: payload,
      );

      final data = res.data ?? res;

      String? extract(dynamic v) {
        if (v is String && v.length > 100) {
          return 'data:image/png;base64,$v';
        }
        if (v is Map) {
          for (final e in v.values) {
            final r = extract(e);
            if (r != null) return r;
          }
        }
        return null;
      }

      if (data is Map && data.containsKey('responseList')) {
        final qr = extract(data['responseList']);
        if (qr != null) return qr;
      }

      return data;
    } catch (e) {
      debugPrint('getQrById -> error: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> esSuscriptorDePlan(String idPlan) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return false;

      final res = await client
          .from('suscripcion')
          .select('id_plan')
          .eq('id_usuario', user.id)
          .eq('id_plan', idPlan)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('esSuscriptorDePlan -> error: $e');
      return false;
    }
  }

  Future<bool> estaSuscrito(String idCreador) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        return false;
      }

      final rpcRes = await client.rpc('esta_suscrito', params: {
        'p_id_usuario': user.id,
        'p_id_creador': idCreador,
      });

      if (rpcRes == null) return false;

      // RPC can return a boolean directly, or a list with a single boolean, or a map.
      if (rpcRes is bool) return rpcRes;

      if (rpcRes is List && rpcRes.isNotEmpty) {
        final first = rpcRes.first;
        if (first is bool) return first;
        if (first is Map) {
          // try to extract a boolean value from the map
          final boolValues = first.values.whereType<bool>().toList();
          if (boolValues.isNotEmpty) return boolValues.first;
        }
      }

      if (rpcRes is Map) {
        final boolValues = rpcRes.values.whereType<bool>().toList();
        if (boolValues.isNotEmpty) return boolValues.first;
      }

      // Fallbacks: string or numeric representations
      if (rpcRes is String) {
        final s = rpcRes.toLowerCase();
        if (s == 'true' || s == 't' || s == '1') return true;
        return false;
      }

      if (rpcRes is num) return rpcRes == 1;

      return false;
    } catch (e) {
      return false;
    }
  }
}