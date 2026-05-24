import '../entities/bot.dart';

/// Puerto de dominio para Bots (S04). Define los verbos que el bloc puede
/// pedir; las implementaciones viven en `data/`.
abstract interface class BotsRepository {
  /// Listado de bots de la org activa. RBAC del backend filtra por rol:
  /// SUPERVISOR+ ven todos; WORKER solo los asignados a su Membership.
  Future<List<Bot>> list();

  /// Detalle de un bot por ID. Lanza `BotsNotFoundFailure` si el ID no
  /// existe en la org activa (404), `BotsForbiddenFailure` si el rol no
  /// alcanza (403), o las variantes de red/timeout/server si el transporte
  /// falla. El bloc traduce a estado de UI.
  Future<Bot> byId(String id);
}
