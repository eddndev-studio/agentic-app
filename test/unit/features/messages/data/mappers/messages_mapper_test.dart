import 'package:ataulfo/features/messages/data/dto/message_dto.dart';
import 'package:ataulfo/features/messages/data/mappers/messages_mapper.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MessageResp resp({
    String kind = 'GROUP',
    String direction = 'OUTBOUND',
    String? status = 'READ',
  }) => MessageResp(
    externalId: 'e1',
    chatLid: 'grupo-1',
    senderLid: 'bot',
    kind: kind,
    direction: direction,
    type: 'text',
    content: 'ey',
    timestampMs: 1800,
    mediaRef: null,
    quotedId: null,
    status: status,
  );

  group('MessagesMapper.respToMessage', () {
    test('mapea kind/direction/status vía fromWire', () {
      final m = MessagesMapper.respToMessage(resp());
      expect(m.kind, MessageKind.group);
      expect(m.direction, MessageDirection.outbound);
      expect(m.status, MessageStatus.read);
      expect(m.content, 'ey');
    });

    test('status ausente (INBOUND) → null', () {
      final m = MessagesMapper.respToMessage(
        resp(direction: 'INBOUND', status: null),
      );
      expect(m.status, isNull);
    });

    test('kind desconocido → ArgumentError (propaga fail-loud)', () {
      expect(
        () => MessagesMapper.respToMessage(resp(kind: 'CHANNEL')),
        throwsArgumentError,
      );
    });
  });

  group('MessagesMapper.respToPage', () {
    test('mapea mensajes + prevCursor', () {
      final page = MessagesMapper.respToPage(
        MessageThreadResp(messages: <MessageResp>[resp()], prevCursor: '1:e0'),
      );
      expect(page.messages, hasLength(1));
      expect(page.messages[0].kind, MessageKind.group);
      expect(page.prevCursor, '1:e0');
    });
  });
}
