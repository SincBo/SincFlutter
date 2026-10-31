import 'package:supabase_flutter/supabase_flutter.dart';

/// Extrae un mensaje de error legible para mostrar en la UI.
///
/// Si es un error de Postgres/Supabase (por ejemplo, una excepción lanzada
/// desde una función RPC con `RAISE EXCEPTION`, como las validaciones de
/// suscripción activa), devuelve el mensaje real en vez de un texto
/// genérico tipo "algo salió mal".
String friendlyErrorMessage(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }
  if (error is AuthException) {
    return error.message;
  }
  return error.toString();
}
