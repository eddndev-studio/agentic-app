import '../../domain/entities/message_page.dart';
import '../../domain/repositories/messages_repository.dart';
import '../datasources/messages_datasource.dart';

/// Implementación trivial del puerto: cada página se trae del backend al vuelo
/// (sin cache local en esta capa). Cuando aterrice RFC-0001 (cache + sync),
/// esta clase orquestará verdad local vs. remota; hoy delega.
class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl({required MessagesDatasource datasource})
    : _ds = datasource;

  final MessagesDatasource _ds;

  @override
  Future<MessagePage> thread(
    String botId,
    String chatLid, {
    String? cursor,
    int? limit,
  }) => _ds.thread(botId, chatLid, cursor: cursor, limit: limit);
}
