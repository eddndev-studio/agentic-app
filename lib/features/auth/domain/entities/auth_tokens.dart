/// Par de tokens emitido por S02 (`/auth/login`, `/auth/refresh`,
/// `/auth/switch-org`). Entidad de dominio, sin nombres del wire.
///
/// `expiresInSeconds` es el TTL del access; el cliente reemite ANTES del
/// vencimiento usando `refreshToken`. Familia y rotación viven en el
/// backend — el cliente sólo conserva el último par vigente.
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresInSeconds,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInSeconds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthTokens &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.tokenType == tokenType &&
        other.expiresInSeconds == expiresInSeconds;
  }

  @override
  int get hashCode =>
      Object.hash(accessToken, refreshToken, tokenType, expiresInSeconds);
}
