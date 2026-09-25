import 'package:finn_code/data/storage/session_codec.dart';
import 'package:finn_code/domain/models/agent_event.dart';
import 'package:finn_code/domain/models/agent_message.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 12, 30);
  final session = AgentSession(
    id: 'session-1',
    title: 'A saved task',
    preview: 'A saved preview',
    providerId: 'finn-demo',
    model: 'finn-demo-v1',
    projectPath: '/tmp/project',
    createdAt: now,
    updatedAt: now,
    status: SessionStatus.failed,
    remoteThreadId: 'thread-1',
    isPinned: true,
    messages: <AgentMessage>[
      AgentMessage(
        id: 'message-1',
        role: MessageRole.user,
        content: 'Run the tests',
        createdAt: now,
        status: MessageStatus.complete,
      ),
      AgentMessage(
        id: 'message-2',
        role: MessageRole.assistant,
        content: 'Done',
        createdAt: now,
        status: MessageStatus.error,
        reasoning: 'Checked the result',
        isFinalAnswer: false,
        events: <AgentEvent>[
          AgentEvent(
            id: 'event-1',
            kind: AgentEventKind.command,
            title: 'Command finished',
            detail: 'flutter test',
            status: AgentEventStatus.completed,
            additions: 3,
            deletions: 1,
          ),
        ],
      ),
    ],
  );

  test('round-trips task history without dropping agent metadata', () {
    final restored = SessionCodec.decode(
      SessionCodec.encode(<AgentSession>[session]),
    );

    expect(restored, hasLength(1));
    final value = restored.single;
    expect(value.id, session.id);
    expect(value.projectPath, '/tmp/project');
    expect(value.status, SessionStatus.failed);
    expect(value.remoteThreadId, 'thread-1');
    expect(value.isPinned, isTrue);
    expect(value.messages, hasLength(2));
    expect(value.messages.last.reasoning, 'Checked the result');
    expect(value.messages.last.isFinalAnswer, isFalse);
    expect(value.messages.last.events.single.additions, 3);
    expect(value.messages.last.events.single.deletions, 1);
  });

  test('accepts the legacy list shape and rejects unknown schema versions', () {
    final legacy = SessionCodec.encode(<AgentSession>[session]);
    final legacyList = legacy.substring(
      legacy.indexOf('['),
      legacy.lastIndexOf(']') + 1,
    );
    expect(SessionCodec.decode(legacyList), hasLength(1));

    expect(SessionCodec.decode('{"version":999,"sessions":[]}'), isEmpty);
    expect(SessionCodec.decode('{not json'), isEmpty);
    expect(SessionCodec.decode('null'), isEmpty);
  });

  test('drops malformed records without losing valid records', () {
    final value =
        '{"version":2,"sessions":['
        '{"id":"valid","title":"T","preview":"P","providerId":"finn-demo",'
        '"model":"m","createdAt":"2026-09-23T00:00:00.000",'
        '"updatedAt":"2026-09-23T00:00:00.000","messages":[]},'
        '{"id":"broken","title":42}]}';

    final restored = SessionCodec.decode(value);
    expect(restored.map((session) => session.id), <String>['valid']);
  });
}
