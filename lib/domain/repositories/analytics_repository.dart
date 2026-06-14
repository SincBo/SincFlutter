import '../../data/datasources/analytics.datasources.dart';
import '../../domain/entities/ganancias_mes.dart';
import '../../domain/entities/top_pago_mes.dart';

class AnalyticsRepository {
  final AnalyticsDataSource analyticsDs;

  AnalyticsRepository(this.analyticsDs);

  // =========================
  // GANANCIAS DEL CREADOR
  // =========================
  Future<List<GananciasMesEntity>> getGananciasCreadorMes({
    required String creadorId,
    required int year,
    required int month,
  }) {
    return analyticsDs.obtenerGananciasCreadorMesModel(
      creadorId: creadorId,
      year: year,
      month: month,
    );
  }

  // =========================
  // TOP PAGOS DEL MES
  // =========================
  Future<List<TopPagoMesEntity>> getTopPagosCreadorMes({
    required String creadorId,
    required int year,
    required int month,
    int limit = 10,
  }) {
    return analyticsDs.obtenerTopPagosCreadorMes(
      creadorId: creadorId,
      year: year,
      month: month,
      limit: limit,
    );
  }

  // =========================
  // GANANCIAS RAW (MAP)
  // =========================
  Future<List<Map<String, dynamic>>> getGananciasRaw({
    required String creadorId,
    required int year,
    required int month,
  }) {
    return analyticsDs.obtenerGananciasCreadorMes(
      creadorId: creadorId,
      year: year,
      month: month,
    );
  }
}