import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finn_code/data/services/codex_app_server_gateway.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

class _CodexTestServer {
  _CodexTestServer();

  late HttpServer _server;
  late StreamSubscription<HttpRequest> _serverSubscription;
  final Set<WebSocket> sockets = <WebSocket>{};
  final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];

  String get url => 'ws://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _serverSubscription = _server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen(
        (raw) => _handleMessage(socket, raw),
        onDone: () => sockets.remove(socket),
        onError: (_) => sockets.remove(socket),
      );
    });
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await _serverSubscription.cancel();
    await _server.close(force: true);
  }

  void _handleMessage(WebSocket socket, Object raw) {
    if (raw is! String) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    messages.add(decoded);
    final method = decoded['method']?.toString();
    final id = decoded['id'];

    if (id == 77 && decoded['result'] != null) {
      _send(socket, <String, Object?>{
        'method': 'item/agentMessage/delta',
        'params': <String, Object?>{
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'itemId': 'message-1',
          'delta': 'Approved and finished',
        },
      });
      _send(socket, <String, Object?>{
        'method': 'item/completed',
        'params': <String, Object?>{
          'threadId': 'thread-1',
          'turnId': 'turn-1',
          'item': <String, Object?>{
            'id': 'message-1',
            'type': 'agentMessage',
            'text': 'Approved and finished',
          },
        },
      });
      _send(socket, <String, Object?>{
        'method': 'turn/completed',
        'params': <String, Object?>{
          'threadId': 'thread-1',
          'turn': <String, Object?>{'id': 'turn-1', 'status': 'completed'},
        },
      });
      return;
    }

    switch (method) {
      case 'initialize':
        _send(socket, <String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'userAgent': 'test',
            'codexHome': '/tmp',
            'platformFamily': 'unix',
            'platformOs': 'macos',
          },
        });
      case 'model/list':
        _send(socket, <String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'data': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'test-model',
                'displayName': 'Test Model',
              },
            ],
          },
        });
      case 'thread/start':
        _send(socket, <String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'thread': <String, Object?>{'id': 'thread-1'},
          },
        });
      case 'turn/start':
        _send(socket, <String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'turn': <String, Object?>{'id': 'turn-1'},
          },
        });
        _send(socket, <String, Object?>{
          'method': 'turn/started',
          'params': <String, Object?>{
            'threadId': 'thread-1',
            'turn': <String, Object?>{'id': 'turn-1'},
          },
        });
        _send(socket, <String, Object?>{
          'id': 77,
          'method': 'item/commandExecution/requestApproval',
          'params': <String, Object?>{
            'threadId': 'thread-1',
            'turnId': 'turn-1',
            'itemId': 'command-1',
            'command': 'echo approved',
            'reason': 'Testing the approval path',
          },
        });
    }
  }

  void _send(WebSocket socket, Map<String, Object?> message) {
    socket.add(jsonEncode(message));
  }
}

void main() {
  test(
    'handles a real bidirectional Codex turn and approval response',
    () async {
      final server = _CodexTestServer();
      await server.start();
      addTearDown(server.close);

      final gateway = CodexAppServerGateway();
      addTearDown(gateway.dispose);
      final provider = ProviderConfig(
        id: 'codex',
        name: 'Codex test',
        protocol: ProviderProtocol.codex,
        baseUrl: server.url,
        model: '',
      );
      final session = AgentSession(
        id: 'session',
        title: 'Test',
        preview: '',
        providerId: provider.id,
        model: '',
        createdAt: DateTime(2026, 9, 24),
        updatedAt: DateTime(2026, 9, 24),
      );

      await gateway.testConnection(provider);
      final models = await gateway.listModels(provider);
      expect(models.single.id, 'test-model');

      final updates = <AgentStreamUpdate>[];
      final completed = Completer<void>();
      final subscription = gateway
          .streamReply(
            session: session,
            prompt: 'run the guarded command',
            provider: provider,
          )
          .listen(
            (update) {
              updates.add(update);
              if (update is AgentApprovalRequired) {
                unawaited(
                  gateway.respondToApproval(
                    provider: provider,
                    request: update.request,
                    approve: true,
                    allowForSession: false,
                  ),
                );
              }
            },
            onDone: completed.complete,
            onError: (Object error, StackTrace stackTrace) {
              if (!completed.isCompleted) {
                completed.completeError(error, stackTrace);
              }
            },
          );
      addTearDown(subscription.cancel);

      await completed.future.timeout(const Duration(seconds: 5));

      expect(
        updates.whereType<AgentRemoteThread>().map((item) => item.threadId),
        contains('thread-1'),
      );
      expect(
        updates.whereType<AgentTextDelta>().map((item) => item.delta).join(),
        'Approved and finished',
      );
      expect(updates.whereType<AgentTurnComplete>(), isNotEmpty);
      expect(
        server.messages.where(
          (message) =>
              message['id'] == 77 &&
              message['result'] is Map &&
              (message['result'] as Map)['decision'] == 'accept',
        ),
        hasLength(1),
      );
    },
  );
}
