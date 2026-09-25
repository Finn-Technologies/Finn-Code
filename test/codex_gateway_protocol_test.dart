import 'package:finn_code/data/services/codex_app_server_gateway.dart';
import 'package:finn_code/domain/models/agent_event.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds valid command and file approval responses', () {
    final gateway = CodexAppServerGateway();
    final command = ApprovalRequest(
      requestId: 1,
      kind: ApprovalKind.command,
      title: 'Run command',
    );
    final fileChange = ApprovalRequest(
      requestId: 2,
      kind: ApprovalKind.fileChange,
      title: 'Apply files',
    );

    expect(
      gateway.approvalResponse(
        request: command,
        approve: true,
        allowForSession: false,
      ),
      <String, Object?>{'decision': 'accept'},
    );
    expect(
      gateway.approvalResponse(
        request: fileChange,
        approve: true,
        allowForSession: true,
      ),
      <String, Object?>{'decision': 'acceptForSession'},
    );
    expect(
      gateway.approvalResponse(
        request: command,
        approve: false,
        allowForSession: true,
      ),
      <String, Object?>{'decision': 'decline'},
    );
  });

  test('denied permission requests fail closed with the required shape', () {
    final gateway = CodexAppServerGateway();
    final request = ApprovalRequest(
      requestId: 3,
      kind: ApprovalKind.permission,
      title: 'Grant permissions',
      rawParams: <String, dynamic>{
        'permissions': <String, Object?>{'network': <String, Object?>{}},
      },
    );

    expect(
      gateway.approvalResponse(
        request: request,
        approve: false,
        allowForSession: true,
      ),
      <String, Object?>{'permissions': <String, Object?>{}, 'scope': 'session'},
    );
  });

  test('maps interrupted Codex turns to a terminal failure', () {
    final updates = codexTurnCompletionUpdates(<String, dynamic>{
      'status': 'interrupted',
    });

    expect(updates, hasLength(2));
    expect(updates.first, isA<AgentEventUpdate>());
    expect(updates.last, isA<AgentFailure>());
    expect(
      (updates.first as AgentEventUpdate).event.status,
      AgentEventStatus.declined,
    );
  });
}
