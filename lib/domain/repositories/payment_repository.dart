import '../../data/datasources/payment.datasource.dart';

class PaymentRepository {
  final PaymentDataSource paymentDs;

  PaymentRepository(this.paymentDs);

  // =========================
  // CREAR TRANSACCIÓN
  // =========================
  Future<String?> createTransaction({
    required String creatorId,
    required String planId,
    required double price,
  }) {
    return paymentDs.createTransaction(
      creatorId: creatorId,
      planId: planId,
      price: price,
    );
  }

  // =========================
  // GENERAR QR DE PAGO
  // =========================
  Future<dynamic> generateQr({
    required double amount,
    required String gloss,
    required String destinationAccountId,
    String? additionalData,
    String? callbackUrl,
    String? transactionIdentifier,
  }) {
    return paymentDs.generateQr(
      amount: amount,
      gloss: gloss,
      destinationAccountId: destinationAccountId,
      additionalData: additionalData,
      callbackUrl: callbackUrl,
      transactionIdentifier: transactionIdentifier,
    );
  }

  // =========================
  // OBTENER QR POR ID
  // =========================
  Future<dynamic> getQrById(String id) {
    return paymentDs.getQrById(id);
  }

  // =========================
  // VERIFICAR SUSCRIPCIÓN
  // =========================
  Future<bool> isSubscribedToPlan(String planId) {
    return paymentDs.esSuscriptorDePlan(planId);
  }

  Future<bool> isSubscribedToCreator(String creatorId) {
    return paymentDs.estaSuscrito(creatorId);
  }
}