import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../providers/providers.dart';

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

  const PaymentConfirmationPage({
    Key? key,
    this.recipient = 'pablo',
    this.amount = '50 bs',
    this.concept = 'suscripción/solicitud',
    this.destinationAccountId = '3332CO',
    this.additionalData,
    this.callbackUrl = 'https://tuapp.com/api/callback',
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Prepare a Future that calls the datasource.generateQr using the project's provider
    final parsedAmount = double.tryParse(amount.replaceAll(RegExp('[^0-9.]'), '')) ?? 0.0;
    // Do not call the Edge function if the amount is invalid (<= 0).
    AsyncValue<dynamic>? qrAsync;
    if (parsedAmount > 0) {
      qrAsync = ref.watch(_generateQrFutureProvider([
        parsedAmount,
        concept,
        destinationAccountId,
        additionalData ?? 'Pago ${amount}',
        callbackUrl,
      ]));
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
              final ds = ref.read(supabaseDataSourceProvider);
              final testAmount = parsedAmount > 0 ? parsedAmount : 10.0;
              final body = {
                'amount': testAmount,
                'gloss': concept,
                'additionalData': additionalData ?? 'Pago $amount',
                'destinationAccountId': destinationAccountId,
                'callbackUrl': callbackUrl,
              };

              showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
              dynamic res;
              try {
                res = await ds.generateQr(
                  amount: testAmount,
                  gloss: concept,
                  additionalData: additionalData ?? 'Pago $amount',
                  destinationAccountId: destinationAccountId,
                  callbackUrl: callbackUrl,
                );
              } catch (e) {
                res = {'ok': false, 'error': e.toString(), 'body': body};
              }

              if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // dismiss loading

              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Debug generateQr result'),
                  content: SingleChildScrollView(child: SelectableText(JsonEncoder.withIndent('  ').convert(res))),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar'))],
                ),
              );
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
                            child: _buildQrContent(context, theme, qrAsync, parsedAmount, amount, concept, destinationAccountId, additionalData, callbackUrl, ref),
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

  Widget _buildQrContent(BuildContext context, ThemeData theme, AsyncValue<dynamic>? qrAsync, double parsedAmount, String amount, String concept, String destinationAccountId, String? additionalData, String? callbackUrl, WidgetRef ref) {
    // Handle null or invalid amount
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
        // If the datasource returned a structured error (ok: false), show it
        if (res is Map && (res['ok'] == false || res.containsKey('error'))) {
          final errMsg = res['error'] ?? res['message'] ?? res.toString();
          final sentBody = res['body'] != null ? res['body'].toString() : 'N/A';
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text('Error al generar QR', style: theme.textTheme.titleMedium?.copyWith(color: Colors.redAccent)),
              const SizedBox(height: 6),
              Text(errMsg, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Request body enviado:', style: theme.textTheme.bodySmall),
              SelectableText(sentBody, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => ref.refresh(_generateQrFutureProvider([parsedAmount, concept, destinationAccountId, additionalData ?? 'Pago ${amount}', callbackUrl])), child: const Text('Reintentar')),
            ],
          );
        }

        // Handle successful responses
        if (res == null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code, size: 92, color: theme.colorScheme.primary.withAlpha(230)),
              const SizedBox(height: 12),
              Text('QR de pago', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
            ],
          );
        }

        if (res is String) {
          final s = res.trim();
          if (s.startsWith('http')) {
            return Image.network(s, width: 200, height: 200, fit: BoxFit.contain);
          }
          if (s.contains('base64')) {
            try {
              final bytes = Uri.parse(s).data?.contentAsBytes();
              if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
            } catch (_) {}
          }
          return SelectableText(s, textAlign: TextAlign.center);
        }

        if (res is Map) {
          final candidates = ['qr_url', 'qr', 'url', 'data', 'image', 'qr_image'];
          for (final k in candidates) {
            if (res.containsKey(k)) {
              final v = res[k];
              if (v is String && v.startsWith('http')) {
                return Image.network(v, width: 200, height: 200, fit: BoxFit.contain);
              }
              if (v is String && v.contains('base64')) {
                try {
                  final bytes = Uri.parse(v).data?.contentAsBytes();
                  if (bytes != null) return Image.memory(bytes, width: 200, height: 200, fit: BoxFit.contain);
                } catch (_) {}
              }
            }
          }

          final payload = res.values.whereType<String>().firstWhere((_) => true, orElse: () => '');
          if (payload.isNotEmpty && payload.startsWith('http')) {
            return Image.network(payload, width: 200, height: 200, fit: BoxFit.contain);
          }

          return Text(res.toString());
        }

        // Default fallback
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 92, color: theme.colorScheme.primary.withAlpha(230)),
            const SizedBox(height: 12),
            Text('QR de pago', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text('No se pudo generar el QR', textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(err.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ElevatedButton(onPressed: () => ref.refresh(_generateQrFutureProvider([parsedAmount, concept, destinationAccountId, additionalData ?? 'Pago ${amount}', callbackUrl])), child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

// Provider to generate QR via Supabase datasource. Returns dynamic payload from the edge function.
final _generateQrFutureProvider = FutureProvider.family<dynamic, List<dynamic>>((ref, params) async {
  // params: [amountDouble, glossString, destinationAccountIdString, additionalData?, callbackUrl?]
  final ds = ref.read(supabaseDataSourceProvider);
  final amount = (params.isNotEmpty && params[0] is double) ? params[0] as double : 0.0;
  final gloss = (params.length > 1 && params[1] is String) ? params[1] as String : 'Pago';
  final destination = (params.length > 2 && params[2] is String) ? params[2] as String : '3332CO';
  final additional = (params.length > 3 && params[3] is String) ? params[3] as String : null;
  final callback = (params.length > 4 && params[4] is String) ? params[4] as String : null;

  try {
    final res = await ds.generateQr(
      amount: amount,
      gloss: gloss,
      additionalData: additional,
      destinationAccountId: destination,
      callbackUrl: callback,
    );
    return res;
  } catch (e) {
    debugPrint('_generateQrFutureProvider -> error: $e');
    throw e;
  }
});
