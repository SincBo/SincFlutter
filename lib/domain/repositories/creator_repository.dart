import '../../data/datasources/creator.datasource.dart';
import '../../domain/entities/creator.dart';
import '../../domain/entities/creator_por_tipo.dart';
import '../../domain/entities/usuario_por_tipo.dart';

class CreatorRepository {
  final CreatorDataSource creatorDs;

  CreatorRepository(this.creatorDs);

  // =========================
  // OBTENER CREADORES (FEED)
  // =========================
  Future<List<CreatorEntity>> getCreators() {
    return creatorDs.obtenerCreadores();
  }

  // =========================
  // BUSCAR CREADORES
  // =========================
  Future<List<CreatorEntity>> searchCreators(
      String query, {
        int limit = 50,
        int offset = 0,
      }) {
    return creatorDs.buscarCreadores(
      query,
      limit: limit,
      offset: offset,
    );
  }

  // =========================
  // CREADORES POR TIPO DE PLAN
  // =========================
  Future<List<CreatorPorTipoEntity>> getCreatorsByType(
      String planType, {
        int limit = 50,
        int offset = 0,
      }) {
    return creatorDs.obtenerCreadoresPorTipo(
      planType,
      limit: limit,
      offset: offset,
    );
  }

  // =========================
  // USUARIOS SUSCRITOS POR TIPO
  // =========================
  Future<List<UsuarioPorTipoEntity>> getUsersByType(
      String planType, {
        int limit = 50,
        int offset = 0,
      }) {
    return creatorDs.obtenerUsuarioPorTipo(
      planType,
      limit: limit,
      offset: offset,
    );
  }
}