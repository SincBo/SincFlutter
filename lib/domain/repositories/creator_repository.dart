

import '../entities/creator.dart';
import '../entities/creator_por_tipo.dart';
import '../entities/usuario_por_tipo.dart';

abstract class CreatorRepository {

  Future<List<CreatorEntity>> getCreators();

  Future<List<CreatorEntity>> searchCreators(
      String query, {
        int limit = 50,
        int offset = 0,
      });

  Future<List<CreatorPorTipoEntity>> getCreatorsByType(
      String planType, {
        int limit = 50,
        int offset = 0,
      });

  Future<List<UsuarioPorTipoEntity>> getUsersByType(
      String planType, {
        int limit = 50,
        int offset = 0,
      });
}