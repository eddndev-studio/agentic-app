/// Failures de autenticación expuestas por la capa de datos.
///
/// Son `Exception` (no `Error`): el llamador es el bloc, que las atrapa y
/// las traduce a estados de UI. La jerarquía es sellada para forzar al
/// switch del bloc a cubrir todos los casos: un failure nuevo rompe el
/// build, no se cuela silencioso.
sealed class AuthFailure implements Exception {
  const AuthFailure();
}

/// 401 contra `/auth/login`: credenciales incorrectas.
final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// 429 contra `/auth/login`: rate limit (S02 RF#9). El cliente debe
/// reintentar tras un backoff (mensaje "intenta en un momento").
final class RateLimitedFailure extends AuthFailure {
  const RateLimitedFailure();
}

/// Timeout, sin conexión, DNS, TLS. Reintentable por acción del usuario.
final class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

/// Cualquier otro status (5xx, body malformado, etc.). El backend o el
/// transporte rompieron de forma no contemplada — el cliente lo expone
/// como error genérico sin filtrar el status crudo.
final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure();
}
