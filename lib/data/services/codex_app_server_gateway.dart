import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_session.dart';
import '../../domain/models/agent_stream_update.dart';
import '../../domain/models/model_info.dart';
import '../../domain/models/provider_config.dart';
import '../../domain/services/agent_gateway.dart';
import 'sse.dart';

class CodexAppServerGateway implements AgentGateway {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _connectedUrl;
  int _nextRequestId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  final Map<String, AgentSession> _sessionsByThread = <String, AgentSession>{};
  final Set<String> _streamedMessageItemIds = <String>{};
  StreamController<AgentStreamUpdate>? _runController;
  String? _activeThreadId;
  String? _activeTurnId;

  Future<void> _ensureConnected(ProviderConfig provider) async {
    final normalized = _normalizeUrl(provider.baseUrl);
    if (_channel != null && _connectedUrl == normalized) {
      try {
        await _channel!.ready;
        return;
      } on Object {
        await _closeConnection();
      }
    }
    await _closeConnection();
    final channel = IOWebSocketChannel.connect(
      normalized,
      headers: <String, dynamic>{
        if (provider.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${provider.apiKey}',
      },
      pingInterval: const Duration(seconds: 20),
      connectTimeout: const Duration(seconds: 12),
    );
    await channel.ready;
    _channel = channel;
    _connectedUrl = normalized;
    _subscription = channel.stream.listen(
      _handleMessage,
      onError: (Object error, StackTrace stackTrace) {
        _failConnection('Codex gateway error: $error');
      },
      onDone: () {
        _failConnection('Codex gateway disconnected.');
      },
      cancelOnError: false,
    );

    await _request('initialize', <String, Object?>{
      'clientInfo': <String, Object?>{
        'name': 'finn_code_mobile',
        'title': 'Finn Code',
        'version': '0.1.0',
      },
      'capabilities': <String, Object?>{'experimentalApi': true},
    });
    _sendNotification('initialized', <String, Object?>{});
  }

  String _normalizeUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) {
      throw const AgentGatewayException('Codex Gateway URL is required.');
    }
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
    }
    return url;
  }

  void _send(Map<String, Object?> message) {
    final channel = _channel;
    if (channel == null) {
      throw const AgentGatewayException('Codex Gateway is not connected.');
    }
    channel.sink.add(jsonEncode(message));
  }

  void _sendNotification(String method, Map<String, Object?> params) {
    _send(<String, Object?>{'method': method, 'params': params});
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, Object?> params,
  ) async {
    final id = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send(<String, Object?>{'id': id, 'method': method, 'params': params});
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _pending.remove(id);
      throw AgentGatewayException('Codex request timed out: $method');
    }
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return;
    }

    final method = message['method']?.toString();
    final id = message['id'];
    if (method != null && id != null) {
      _handleServerRequest(id, method, _asMap(message['params']));
      return;
    }

    if (id is int && _pending.containsKey(id)) {
      final completer = _pending.remove(id)!;
      final error = message['error'];
      if (error != null) {
        completer.completeError(
          AgentGatewayException(
            error['message']?.toString() ?? 'Codex request failed.',
            statusCode: (error['code'] as num?)?.toInt(),
          ),
        );
      } else {
        completer.complete(_asMap(message['result']));
      }
      return;
    }

    if (method != null) {
      _handleNotification(method, _asMap(message['params']));
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, item) => MapEntry('$key', item));
    return <String, dynamic>{};
  }

  void _emit(AgentStreamUpdate update) {
    final controller = _runController;
    if (controller == null || controller.isClosed) return;
    controller.add(update);
  }

  void _handleNotification(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'thread/started':
        final thread = _asMap(params['thread']);
        final threadId = thread['id']?.toString();
        if (threadId != null) _emit(AgentRemoteThread(threadId));
      case 'turn/started':
        final turn = _asMap(params['turn']);
        _activeTurnId = turn['id']?.toString();
        _emit(
          const AgentEventUpdate(
            AgentEvent(
              id: 'turn',
              kind: AgentEventKind.status,
              title: 'Agent turn started',
              detail: 'Streaming model and tool activity',
            ),
          ),
        );
      case 'turn/plan/updated':
        final plan = params['plan'];
        _emit(
          AgentEventUpdate(
            AgentEvent(
              id: 'plan-${params['turnId'] ?? 'current'}',
              kind: AgentEventKind.status,
              title: 'Plan updated',
              detail: _planSummary(plan),
            ),
          ),
        );
      case 'item/reasoning/summaryTextDelta':
      case 'item/reasoning/textDelta':
        final delta = params['delta']?.toString();
        if (delta != null && delta.isNotEmpty) {
          _emit(AgentReasoningDelta(delta));
        }
      case 'item/agentMessage/delta':
        final itemId = params['itemId']?.toString();
        final delta = params['delta']?.toString();
        if (itemId != null) _streamedMessageItemIds.add(itemId);
        if (delta != null && delta.isNotEmpty) {
          _emit(AgentTextDelta(delta));
        }
      case 'item/started':
        final event = _eventFromItem(_asMap(params['item']));
        if (event != null) _emit(AgentEventUpdate(event));
      case 'item/completed':
        final item = _asMap(params['item']);
        final completed = _eventFromItem(item, completed: true);
        if (completed != null) _emit(AgentEventUpdate(completed));
        final itemId = item['id']?.toString();
        if (item['type'] == 'agentMessage' &&
            itemId != null &&
            !_streamedMessageItemIds.contains(itemId)) {
          final text = item['text']?.toString();
          if (text != null && text.isNotEmpty) {
            _streamedMessageItemIds.add(itemId);
            _emit(AgentTextDelta(text));
          }
        }
      case 'thread/tokenUsage/updated':
        final usage = _asMap(params['tokenUsage']);
        final last = _asMap(usage['last']);
        final total = _asMap(usage['total']);
        final inputTokens =
            (last['inputTokens'] ?? total['inputTokens']) as num?;
        final outputTokens =
            (last['outputTokens'] ?? total['outputTokens']) as num?;
        _emit(
          AgentTurnComplete(
            inputTokens: inputTokens?.toInt(),
            outputTokens: outputTokens?.toInt(),
          ),
        );
      case 'warning':
        final message = params['message']?.toString();
        if (message != null && message.isNotEmpty) {
          _emit(
            AgentEventUpdate(
              AgentEvent(
                id: 'warning-${params['threadId'] ?? 'current'}',
                kind: AgentEventKind.status,
                title: 'Runtime warning',
                detail: message,
                status: AgentEventStatus.completed,
              ),
            ),
          );
        }
      case 'item/commandExecution/outputDelta':
        final delta = params['delta']?.toString();
        if (delta != null && delta.isNotEmpty) {
          _emit(
            AgentEventUpdate(
              AgentEvent(
                id: 'command-output',
                kind: AgentEventKind.command,
                title: 'Command output',
                detail: delta,
              ),
            ),
          );
        }
      case 'turn/diff/updated':
        final diff = params['diff']?.toString() ?? '';
        if (diff.isNotEmpty) {
          final counts = _diffCounts(diff);
          _emit(
            AgentEventUpdate(
              AgentEvent(
                id: 'diff-${params['turnId'] ?? 'current'}',
                kind: AgentEventKind.diff,
                title: 'Files changed',
                detail: _changedFiles(diff),
                status: AgentEventStatus.completed,
                additions: counts.$1,
                deletions: counts.$2,
              ),
            ),
          );
        }
      case 'turn/completed':
        final turn = _asMap(params['turn']);
        for (final update in codexTurnCompletionUpdates(turn)) {
          _emit(update);
        }
        _finishRun();
      case 'error':
        final error = _asMap(params['error']);
        _emit(
          AgentFailure(error['message']?.toString() ?? 'Unknown Codex error.'),
        );
        _finishRun();
    }
  }

  AgentEvent? _eventFromItem(
    Map<String, dynamic> item, {
    bool completed = false,
  }) {
    final id = item['id']?.toString() ?? 'item';
    final type = item['type']?.toString();
    final status = completed
        ? AgentEventStatus.completed
        : AgentEventStatus.running;
    return switch (type) {
      'commandExecution' => AgentEvent(
        id: id,
        kind: AgentEventKind.command,
        title: completed ? 'Command finished' : 'Running command',
        detail: item['command']?.toString() ?? item['cwd']?.toString() ?? '',
        status: status,
      ),
      'fileChange' => AgentEvent(
        id: id,
        kind: AgentEventKind.fileChange,
        title: completed ? 'File changes ready' : 'Editing files',
        detail: _fileChangeSummary(item['changes']),
        status: status,
      ),
      'mcpToolCall' || 'dynamicToolCall' || 'webSearch' => AgentEvent(
        id: id,
        kind: AgentEventKind.tool,
        title: completed ? 'Tool finished' : 'Using ${item['tool'] ?? type}',
        detail: item['query']?.toString() ?? item['server']?.toString() ?? '',
        status: status,
      ),
      _ => null,
    };
  }

  String _planSummary(Object? value) {
    if (value is! List) return '';
    return value
        .whereType<Map>()
        .map((step) => '${step['status'] ?? 'pending'} · ${step['step'] ?? ''}')
        .join('\n');
  }

  String _fileChangeSummary(Object? value) {
    if (value is! List) return '';
    return value
        .whereType<Map>()
        .map((change) => change['path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .take(4)
        .join('\n');
  }

  (int, int) _diffCounts(String diff) {
    var additions = 0;
    var deletions = 0;
    for (final line in diff.split('\n')) {
      if (line.startsWith('+') && !line.startsWith('+++')) additions++;
      if (line.startsWith('-') && !line.startsWith('---')) deletions++;
    }
    return (additions, deletions);
  }

  String _changedFiles(String diff) {
    final files = <String>{};
    for (final line in diff.split('\n')) {
      if (line.startsWith('+++ b/')) files.add(line.substring(6));
      if (line.startsWith('--- a/')) files.add(line.substring(6));
    }
    return files.take(4).join('\n');
  }

  void _handleServerRequest(
    Object id,
    String method,
    Map<String, dynamic> params,
  ) {
    final command = params['command']?.toString();
    final cwd = params['cwd']?.toString();
    final approval = switch (method) {
      'item/commandExecution/requestApproval' => ApprovalRequest(
        requestId: id,
        kind: ApprovalKind.command,
        title: 'Run this command?',
        detail: params['reason']?.toString() ?? '',
        command: command,
        cwd: cwd,
        rawParams: params,
      ),
      'item/fileChange/requestApproval' => ApprovalRequest(
        requestId: id,
        kind: ApprovalKind.fileChange,
        title: 'Apply these file changes?',
        detail: params['reason']?.toString() ?? '',
        cwd: cwd,
        rawParams: params,
      ),
      'item/permissions/requestApproval' => ApprovalRequest(
        requestId: id,
        kind: ApprovalKind.permission,
        title: 'Grant additional permissions?',
        detail: params['reason']?.toString() ?? cwd ?? '',
        cwd: cwd,
        rawParams: params,
      ),
      _ => null,
    };
    if (approval != null) {
      _emit(AgentApprovalRequired(approval));
      return;
    }
    _send(<String, Object?>{
      'id': id,
      'error': <String, Object?>{
        'code': -32601,
        'message': 'Finn Code does not handle $method yet.',
      },
    });
  }

  Future<void> _finishRun() async {
    final controller = _runController;
    _runController = null;
    _activeTurnId = null;
    if (controller != null && !controller.isClosed) await controller.close();
  }

  void _failConnection(String message) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(AgentGatewayException(message));
      }
    }
    _pending.clear();
    _emit(AgentFailure(message));
    unawaited(_finishRun());
    unawaited(_closeConnection());
  }

  Future<void> _closeConnection() async {
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    _connectedUrl = null;
    await subscription?.cancel();
    await channel?.sink.close();
  }

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) async* {
    if (_runController != null) {
      throw const AgentGatewayException('A Codex turn is already running.');
    }
    await _ensureConnected(provider);
    final controller = StreamController<AgentStreamUpdate>();
    _runController = controller;
    _streamedMessageItemIds.clear();
    _activeThreadId = session.remoteThreadId;

    try {
      var threadId = session.remoteThreadId;
      if (threadId == null || threadId.isEmpty) {
        final result = await _request('thread/start', <String, Object?>{
          if (session.projectPath.isNotEmpty) 'cwd': session.projectPath,
          if (provider.model.isNotEmpty) 'model': provider.model,
          'approvalPolicy': 'on-request',
          'sandbox': session.projectPath.isEmpty
              ? 'read-only'
              : 'workspace-write',
          'serviceName': 'finn_code_mobile',
        });
        threadId = _asMap(result['thread'])['id']?.toString();
        if (threadId == null || threadId.isEmpty) {
          throw const AgentGatewayException(
            'Codex did not return a thread id.',
          );
        }
        _sessionsByThread[threadId] = session;
        _emit(AgentRemoteThread(threadId));
      } else {
        await _request('thread/resume', <String, Object?>{
          'threadId': threadId,
        });
      }
      _activeThreadId = threadId;

      final turnParams = <String, Object?>{
        'threadId': threadId,
        'input': <Map<String, String>>[
          <String, String>{'type': 'text', 'text': prompt},
        ],
        'approvalPolicy': 'on-request',
        'sandboxPolicy': session.projectPath.isEmpty
            ? <String, Object?>{'type': 'readOnly'}
            : <String, Object?>{
                'type': 'workspaceWrite',
                'writableRoots': <String>[session.projectPath],
                'networkAccess': true,
              },
        if (provider.model.isNotEmpty) 'model': provider.model,
      };
      final turnResult = await _request('turn/start', turnParams);
      _activeTurnId = _asMap(turnResult['turn'])['id']?.toString();
      yield* controller.stream;
    } on Object catch (error) {
      if (!controller.isClosed) {
        controller.add(AgentFailure(error.toString()));
        await controller.close();
      }
      if (identical(_runController, controller)) {
        _runController = null;
      }
    }
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async {
    await _ensureConnected(provider);
    final result = await _request('model/list', <String, Object?>{
      'limit': 100,
      'includeHidden': false,
    });
    final data = result['data'];
    if (data is! List) return const <ModelInfo>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return ModelInfo(
            id: item['id']?.toString() ?? item['model']?.toString() ?? '',
            displayName:
                item['displayName']?.toString() ??
                item['id']?.toString() ??
                'Unknown model',
            isFree: provider.isFreeTier,
            supportsTools: true,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> testConnection(ProviderConfig provider) async {
    await _ensureConnected(provider);
  }

  @override
  Future<void> respondToApproval({
    required ProviderConfig provider,
    required ApprovalRequest request,
    required bool approve,
    required bool allowForSession,
  }) async {
    await _ensureConnected(provider);
    final Object result = approvalResponse(
      request: request,
      approve: approve,
      allowForSession: allowForSession,
    );
    _send(<String, Object?>{'id': request.requestId, 'result': result});
  }

  Map<String, Object?> approvalResponse({
    required ApprovalRequest request,
    required bool approve,
    required bool allowForSession,
  }) {
    return switch (request.kind) {
      ApprovalKind.command || ApprovalKind.fileChange => <String, Object?>{
        'decision': !approve
            ? 'decline'
            : allowForSession
            ? 'acceptForSession'
            : 'accept',
      },
      ApprovalKind.permission => <String, Object?>{
        'permissions': approve
            ? request.rawParams['permissions'] ??
                  _requestedPermissions(request.rawParams)
            : <String, Object?>{},
        'scope': allowForSession ? 'session' : 'turn',
      },
    };
  }

  Map<String, dynamic> _requestedPermissions(Map<String, dynamic> params) {
    return <String, dynamic>{
      if (params['fileSystem'] != null) 'fileSystem': params['fileSystem'],
      if (params['network'] != null) 'network': params['network'],
    };
  }

  @override
  Future<void> interrupt({
    required AgentSession session,
    required ProviderConfig provider,
  }) async {
    final threadId = session.remoteThreadId ?? _activeThreadId;
    final turnId = _activeTurnId;
    if (threadId == null || turnId == null) return;
    await _ensureConnected(provider);
    await _request('turn/interrupt', <String, Object?>{
      'threadId': threadId,
      'turnId': turnId,
    });
  }

  @override
  Future<void> dispose() async {
    await _finishRun();
    await _closeConnection();
  }
}

List<AgentStreamUpdate> codexTurnCompletionUpdates(Map<String, dynamic> turn) {
  final status = turn['status']?.toString();
  if (status == 'failed') {
    final error = turn['error'];
    final detail = error is Map
        ? error['message']?.toString() ?? 'Codex turn failed.'
        : 'Codex turn failed.';
    return <AgentStreamUpdate>[AgentFailure(detail)];
  }
  if (status == 'interrupted') {
    return const <AgentStreamUpdate>[
      AgentEventUpdate(
        AgentEvent(
          id: 'turn',
          kind: AgentEventKind.status,
          title: 'Turn interrupted',
          detail: 'The run was stopped before completion',
          status: AgentEventStatus.declined,
        ),
      ),
      AgentFailure('Codex turn was interrupted.'),
    ];
  }
  return const <AgentStreamUpdate>[
    AgentEventUpdate(
      AgentEvent(
        id: 'turn',
        kind: AgentEventKind.status,
        title: 'Turn complete',
        detail: 'Agent finished successfully',
        status: AgentEventStatus.completed,
      ),
    ),
    AgentTurnComplete(),
  ];
}
