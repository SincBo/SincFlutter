import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/providers/providers.dart';

/// Página de confirmación de pago.
///
/// Esta página muestra tres secciones:
/// 1) AppBar con botón de retroceso y título "Confirmación de pago".
/// 2) Área central con un QR placeholder, texto que indica a quién confirmar el pago
///    y el monto.
/// 3) Sección inferior que describe el concepto: "Por concepto: suscripción/solicitud".
///
/// La página está diseñada para ser reutilizable pasando `recipient`, `amount` y `concept`.
class PaymentConfirmationPage extends ConsumerWidget {
  final String recipient;
  final String amount; // e.g. "50 bs"
  final String concept; // e.g. "suscripción/solicitud"
  final String destinationAccountId; // Destination account for the QR
  final String? additionalData; // optional additional data sent to the edge function
  final String? callbackUrl; // optional callback url
  final String? transactionId; // id_transaccion para el edge

  const PaymentConfirmationPage({
    Key? key,
    this.recipient = 'pablo',
    this.amount = '50',
    this.concept = 'suscripción/solicitud',
    this.destinationAccountId = '3332CO',
    this.additionalData,
    this.transactionId,
    this.callbackUrl = 'https://tuapp.com/api/callback',
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Prepare a Future that calls the datasource.generateQr using the project's provider
    final parsedAmount = double.tryParse(amount.replaceAll(RegExp('[^0-9.]'), '')) ?? 0.0;
    // Do not call the Edge function if the amount is invalid (<= 0).
    AsyncValue<dynamic>? qrAsync;

    // Pack params: include transactionId to use in edge invocation
    final providerParam = jsonEncode([
      parsedAmount,
      concept,
      destinationAccountId,
      additionalData ?? 'Pago ${amount}',
      callbackUrl,
      transactionId ?? '',
    ]);

    if (parsedAmount > 0) {
      qrAsync = ref.watch(_generateQrFutureProvider(providerParam));

      // Listen to provider state changes for debugging and to notify user when data arrives
      ref.listen<AsyncValue<dynamic>>(_generateQrFutureProvider(providerParam), (prev, next) {
        debugPrint('PaymentConfirmationPage -> _generateQrFutureProvider state changed. prev: $prev next: $next');
        // When data arrives, show a brief message (post frame to avoid build conflicts)
        if (next is AsyncData) {
          debugPrint('PaymentConfirmationPage -> QR data arrived: ${next.value}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR cargado')));
            } catch (_) {}
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Confirmación de pago'),
        centerTitle: true,
        actions: [
          // Debug button: invoke generateQr with a known payload and show response
          IconButton(
            tooltip: 'Test QR (debug)',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              final txId = transactionId ?? '';
              showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              dynamic res;
              try {
                res = await client.functions.invoke('vpay-generate-qr', body: {'id_transaccion': txId});
                try { res = res.data ?? res; } catch (_) {}
              } catch (e) {
                res = {'ok': false, 'error': e.toString()};
              }
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Debug edge result'), content: SingleChildScrollView(child: SelectableText(JsonEncoder.withIndent('  ').convert(res))), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar'))]));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección central: QR y textos
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // QR placeholder inside a card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          width: 240,
                          height: 240,
                          padding: const EdgeInsets.all(14),
                          child: Center(
                            child: _buildQrContent(context, theme, qrAsync, parsedAmount, amount, concept, destinationAccountId, additionalData, callbackUrl, ref, providerParam),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Texto de confirmación
                      Text(
                        'Confirmar tu pago a $recipient',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // Monto
                      Text(
                        amount,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Acción: botón confirmar (opcional)
                      ElevatedButton.icon(
                        onPressed: () {
                          // Acción mínima: mostrar un dialogo de confirmación
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmar pago'),
                              content: Text('¿Deseas confirmar el pago de $amount a $recipient?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Confirmar')),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar pago'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sección inferior: concepto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.black54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Por concepto: $concept',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper that extracts a usable QR payload (data URI, raw base64 or nested fields) from the response
  String? _extractQrPayload(dynamic res) {
    if (res == null) return null;

    // If it's a String that contains JSON, try to decode and re-run extraction
    if (res is String && res.isNotEmpty) {
      final trimmed = res.trim();
      // If it looks like JSON, try decode
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final decoded = jsonDecode(trimmed);
          return _extractQrPayload(decoded);
        } catch (_) {
          // not JSON, continue
        }
      }
      return trimmed;
    }

    // If response is a List, try to inspect first elements
    if (res is List && res.isNotEmpty) {
      for (final item in res) {
        final candidate = _extractQrPayload(item);
        if (candidate != null && candidate.isNotEmpty) return candidate;
      }
      return null;
    }

    if (res is Map) {
      // Direct keys
      final keys = ['qr_url', 'qr', 'url', 'data', 'image', 'qr_image', 'identificator'];
      for (final k in keys) {
        if (res.containsKey(k) && res[k] is String && (res[k] as String).isNotEmpty) {
          return (res[k] as String).trim();
        }
      }

      // responseList per documentation
      if (res.containsKey('responseList') && res['responseList'] is List) {
        for (final rl in res['responseList']) {
          if (rl is Map && rl.containsKey('response') && rl['response'] is List) {
            for (final r in rl['response']) {
              if (r is Map) {
                if (r['code'] == 'QR' && r.containsKey('identificator') && r['identificator'] is String) {
                  return (r['identificator'] as String).trim();
                }
                if (r.containsKey('identificator') && r['identificator'] is String) {
                  return (r['identificator'] as String).trim();
                }
              }
            }
          }
        }
      }

      // Fallback: any large string value (likely base64)
      final base64Candidate = res.values.whereType<String>().firstWhere((v) => v.trim().length > 100, orElse: () => '');
      if (base64Candidate.isNotEmpty) return base64Candidate.trim();
    }

    return null;
  }

  Widget _buildQrContent(BuildContext context, ThemeData theme, AsyncValue<dynamic>? qrAsync, double parsedAmount, String amount, String concept, String destinationAccountId, String? additionalData, String? callbackUrl, WidgetRef ref, String providerParam) {
    if (parsedAmount <= 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text('Monto inválido: $amount', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent)),
          const SizedBox(height: 8),
          const Text('Asegúrate de que el precio sea un número mayor que 0.'),
        ],
      );
    }

    return qrAsync!.when<Widget>(
      data: (res) {
        // Edge success shape { success: true, idQr, qr }
        if (res is Map && res.containsKey('qr') && res['qr'] is String) {
          final payload = (res['qr'] as String).trim();
          try {
            final cleaned = payload.replaceAll('\n', '');
            final bytes = base64Decode(cleaned);
            return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
          } catch (_) {
            // Try as data-uri
            try {
              final maybeDataUri = 'data:image/png;base64,$payload';
              final bytes = Uri.parse(maybeDataUri).data?.contentAsBytes();
              if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
            } catch (_) {}
          }
        }

        // Structured error
        if (res is Map && (res['ok'] == false || res.containsKey('error'))) {
          final errMsg = res['error']?.toString() ?? res['message']?.toString() ?? 'Error desconocido';
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text('Error al generar QR', style: theme.textTheme.titleMedium?.copyWith(color: Colors.redAccent), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(errMsg, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => ref.refresh(_generateQrFutureProvider(providerParam)), child: const Text('Reintentar')),
            ],
          );
        }

        // Generic extraction path
        final payload = _extractQrPayload(res);
        if (payload != null && payload.isNotEmpty) {
          final isNumericId = RegExp(r'^\d{3,}$').hasMatch(payload);
          if (isNumericId) {
            final idAsync = ref.watch(_getQrByIdProvider(payload));
            return idAsync.when<Widget>(
              data: (fetched) {
                final p = _extractQrPayload(fetched);
                if (p != null && p.isNotEmpty) {
                  if (p.startsWith('http')) return Image.network(p, width: 200, height: 200, fit: BoxFit.contain);
                  if (p.contains('base64') && p.startsWith('data:')) {
                    try {
                      final bytes = Uri.parse(p).data?.contentAsBytes();
                      if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
                    } catch (_) {}
                  }
                  try {
                    final cleaned = p.replaceAll('\n', '');
                    final bytes = base64Decode(cleaned);
                    return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
                  } catch (_) {
                    try {
                      final maybeDataUri = 'data:image/png;base64,$p';
                      final bytes = Uri.parse(maybeDataUri).data?.contentAsBytes();
                      if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
                    } catch (_) {}
                  }
                }
                return SelectableText(fetched?.toString() ?? 'Sin datos', textAlign: TextAlign.center);
              },
              loading: () => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [CircularProgressIndicator(), SizedBox(height: 8), Text('Obteniendo imagen del QR...')],
              ),
              error: (e, st) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text('No se pudo obtener la imagen del QR', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: () => ref.refresh(_getQrByIdProvider(payload)), child: const Text('Reintentar')),
                ],
              ),
            );
          }

          if (payload.startsWith('http')) {
            return Image.network(payload, width: 200, height: 200, fit: BoxFit.contain);
          }
          if (payload.contains('base64') && payload.startsWith('data:')) {
            try {
              final bytes = Uri.parse(payload).data?.contentAsBytes();
              if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
            } catch (_) {}
          }
          try {
            final cleaned = payload.replaceAll('\n', '');
            final bytes = base64Decode(cleaned);
            return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
          } catch (_) {
            try {
              final maybeDataUri = 'data:image/png;base64,$payload';
              final bytes = Uri.parse(maybeDataUri).data?.contentAsBytes();
              if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
            } catch (_) {}
          }
        }

        if (res is String) {
          return SelectableText(res, textAlign: TextAlign.center);
        }
        if (res is Map) {
          return SelectableText(JsonEncoder.withIndent('  ').convert(res), textAlign: TextAlign.center);
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 92, color: theme.colorScheme.primary.withAlpha(230)),
            const SizedBox(height: 12),
            Text('QR de pago', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
          ],
        );
      },
      loading: () => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [CircularProgressIndicator(), SizedBox(height: 8), Text('Generando QR...')],
      ),
      error: (err, st) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text('No se pudo generar el QR', textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(err.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ElevatedButton(onPressed: () => ref.refresh(_generateQrFutureProvider(providerParam)), child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

// Provider to fetch QR by identifier when generateQr returns an id (e.g. '165805')
final _getQrByIdProvider = FutureProvider.family<dynamic, String>((ref, id) async {
  final client = ref.read(supabaseClientProvider);
  try {
    final resp = await client.functions.invoke('vpay-get-qr', body: {'id': id});
    dynamic data; try { data = resp.data; } catch (_) { data = resp; }
    return data;
  } catch (e) {
    throw e;
  }
});

// Provider to generate QR via Supabase datasource. Returns dynamic payload from the edge function.
final _generateQrFutureProvider = FutureProvider.family<dynamic, String>((ref, paramsJson) async {
  final client = ref.read(supabaseClientProvider);
  final List<dynamic> params = List<dynamic>.from(jsonDecode(paramsJson) as List);
  final txId = (params.length > 5 && params[5] is String) ? params[5] as String : '';
  if (txId.isEmpty) {
    return {'ok': false, 'error': 'missing transaction id'};
  }
  try {
    final resp = await client.functions.invoke('vpay-generate-qr', body: {'id_transaccion': txId});
    dynamic data; try { data = resp.data; } catch (_) { data = resp; }
    return data;
  } catch (e) {
    throw e;
  }
});
