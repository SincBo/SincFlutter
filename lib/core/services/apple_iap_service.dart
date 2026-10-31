import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado que la UI escucha para mostrar mensajes y refrescar estado.
class IapEvent {
  final bool success;
  final String message;
  const IapEvent({required this.success, required this.message});
}

/// Compras dentro de la app con Apple In-App Purchase (solo iOS).
///
/// Flujo:
///  1. [loadProduct] consulta a StoreKit el producto del plan (el
///     `apple_product_id` que creó la Edge Function create-iap-subscription).
///  2. [buy] abre la hoja de pago nativa de Apple.
///  3. Cuando Apple confirma, [purchaseStream] entrega la compra y este
///     servicio la manda a la Edge Function `verify-apple-purchase`
///     (Etapa 3), que valida con Apple y activa la suscripción en la BD.
///  4. SOLO si el servidor confirma, se llama a `completePurchase`. Si falla,
///     la compra queda pendiente y Apple la vuelve a entregar la próxima vez
///     que se inicie el servicio (así el usuario no pierde lo que pagó).
class AppleIapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<IapEvent> _events = StreamController<IapEvent>.broadcast();
  bool _started = false;

  Stream<IapEvent> get events => _events.stream;

  /// Empieza a escuchar compras. Idempotente. No hace nada fuera de iOS.
  void start() {
    if (!Platform.isIOS || _started) return;
    _started = true;
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        debugPrint('AppleIapService.purchaseStream -> error: $e');
        _events.add(const IapEvent(
          success: false,
          message: 'Ocurrió un error con la tienda de Apple. Inténtalo de nuevo.',
        ));
      },
    );
  }

  void dispose() {
    _sub?.cancel();
    _events.close();
  }

  /// Devuelve el producto de StoreKit (con su precio ya localizado) o null
  /// si no está disponible (aún no aprobado por Apple, tienda no disponible...).
  Future<ProductDetails?> loadProduct(String productId) async {
    if (!Platform.isIOS) return null;
    try {
      if (!await _iap.isAvailable()) return null;
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        debugPrint('AppleIapService.loadProduct -> ${response.error}');
      }
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first;
    } catch (e) {
      debugPrint('AppleIapService.loadProduct -> error: $e');
      return null;
    }
  }

  /// Lanza la hoja de compra de Apple. El resultado llega por [events].
  Future<void> buy(ProductDetails product) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: userId,
    );
    // En este plugin las suscripciones también se compran con buyNonConsumable.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Requerido por Apple: permite recuperar compras hechas antes
  /// (por ejemplo, tras reinstalar la app o cambiar de teléfono).
  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break; // Apple todavía está procesando; esperamos.

        case PurchaseStatus.error:
          debugPrint('AppleIapService: compra con error: ${purchase.error}');
          _events.add(const IapEvent(
            success: false,
            message: 'No se pudo completar la compra.',
          ));
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _events.add(const IapEvent(success: false, message: 'Compra cancelada.'));
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(purchase);
          break;
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'verify-apple-purchase',
        body: {
          'product_id': purchase.productID,
          'transaction_id': purchase.purchaseID,
          // Recibo de la app en base64 (StoreKit 1). La Etapa 3 decide
          // cómo validarlo contra Apple.
          'receipt': purchase.verificationData.serverVerificationData,
          'restored': purchase.status == PurchaseStatus.restored,
        },
      );

      final data = response.data;
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        throw Exception('Respuesta no válida del servidor: $data');
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      // active == false: compra vencida o reembolsada (por ejemplo al
      // restaurar una suscripción antigua). Se da por procesada, pero no hay
      // nada que activar.
      if (data['active'] == false) {
        _events.add(const IapEvent(
          success: false,
          message: 'Esa suscripción ya no está vigente. Puedes suscribirte de nuevo.',
        ));
        return;
      }
      _events.add(const IapEvent(
        success: true,
        message: '¡Suscripción activada!',
      ));
    } catch (e) {
      // NO completamos la compra: queda pendiente y se reintenta luego.
      debugPrint('AppleIapService._verifyAndComplete -> error: $e');
      _events.add(const IapEvent(
        success: false,
        message:
            'Tu pago se recibió pero aún no pudimos activar la suscripción. '
            'No se te cobrará de nuevo; vuelve a abrir la app en unos minutos '
            'o toca "Restaurar compras".',
      ));
    }
  }
}

final appleIapServiceProvider = Provider<AppleIapService>((ref) {
  final service = AppleIapService()..start();
  ref.onDispose(service.dispose);
  return service;
});

/// Producto de StoreKit por `apple_product_id` (null si no está disponible).
final appleProductProvider =
    FutureProvider.family<ProductDetails?, String>((ref, productId) {
  return ref.read(appleIapServiceProvider).loadProduct(productId);
});
