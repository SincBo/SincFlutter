import '../../domain/entities/creator.dart';
import '../../domain/entities/creator_por_tipo.dart';
import '../../domain/entities/usuario_por_tipo.dart';
import '../../domain/repositories/creator_repository.dart';
import '../datasources/creator.datasource.dart';

class CreatorRepositoryImpl implements CreatorRepository {
  final CreatorDataSource _ds;

  CreatorRepositoryImpl(this._ds);

  @override
  Future<List<CreatorEntity>> getCreators() {
    return _ds.obtenerCreadores();
  }

  @override
  Future<List<CreatorEntity>> searchCreators(
    String query, {
    int limit = 50,
    int offset = 0,
  }) {
    return _ds.buscarCreadores(query, limit: limit, offset: offset);
  }

  @override
  Future<List<CreatorPorTipoEntity>> getCreatorsByType(
    String planType, {
    int limit = 50,
    int offset = 0,
  }) {
    return _ds.obtenerCreadoresPorTipo(planType, limit: limit, offset: offset);
  }

  @override
  Future<List<UsuarioPorTipoEntity>> getUsersByType(
    String planType, {
    int limit = 50,
    int offset = 0,
  }) {
    return _ds.obtenerUsuarioPorTipo(planType, limit: limit, offset: offset);
  }
}
