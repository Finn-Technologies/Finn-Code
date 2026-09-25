import 'dart:async';

import 'package:finn_code/data/repositories/agent_repository.dart';
import 'package:finn_code/data/services/android_runtime_bridge.dart';
import 'package:finn_code/data/storage/app_settings_store.dart';
import 'package:finn_code/domain/models/agent_message.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/model_info.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:finn_code/domain/services/agent_gateway.dart';
import 'package:finn_code/viewmodels/app_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MemorySecretStore implements SecretStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _ControlledGateway implements AgentGateway {
  final List<_ControlledRun> runs = <_ControlledRun>[];
  final List<ApprovalRequest> approvals = <ApprovalRequest>[];
  int interruptCount = 0;
  int disposeCount = 0;
  bool throwOnStream = false;
  List<ModelInfo> models = const <ModelInfo>[];
  bool failModelList = false;
  Completer<void>? modelListGate;
  Completer<void>? approvalGate;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) {
    if (throwOnStream) {
      throw StateError('gateway setup failed');
    }
    final run = _ControlledRun(session: session, prompt: prompt);
    runs.add(run);
    return run.controller.stream;
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async {
    await modelListGate?.future;
    if (failModelList) throw StateError('model discovery failed');
    return models;
  }

  @override
  Future<void> testConnection(ProviderConfig provider) async {}

  @override
  Future<void> respondToApproval({
    required ProviderConfig provider,
    required ApprovalRequest request,
    required bool approve,
    required bool allowForSession,
  }) async {
    await approvalGate?.future;
    approvals.add(request);
  }

  @override
  Future<void> interrupt({
    required AgentSession session,
    required ProviderConfig provider,
  }) async {
    interruptCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

class _ControlledRun {
  _ControlledRun({required this.session, required this.prompt});

  final AgentSession session;
  final String prompt;
  final StreamController<AgentStreamUpdate> controller =
      StreamController<AgentStreamUpdate>();
}

class _WorkspaceRuntime extends AndroidRuntimeBridge {
  final Map<String, String> files = <String, String>{'notes.txt': 'original'};
  AndroidCommandResult commandResult = const AndroidCommandResult(
    exitCode: 0,
    output: 'workspace\nnotes.txt',
  );

  @override
  Future<AndroidRuntimeInfo?> getInfo() async => const AndroidRuntimeInfo(
    runtimeId: 'android-test',
    platform: 'Android test',
    workspaceName: 'Test workspace',
    workspacePath: '/data/test/workspace',
    storageBytes: 0,
  );

  @override
  Future<List<Map<String, Object?>>> listFiles({String path = '.'}) async {
    return <Map<String, Object?>>[
      for (final entry in files.entries)
        <String, Object?>{
          'name': entry.key.split('/').last,
          'path': entry.key,
          'isDirectory': false,
          'size': entry.value.length,
          'modified': 0,
        },
    ];
  }

  @override
  Future<String> readFile(String path) async => files[path] ?? '';

  @override
  Future<void> writeFile(String path, String content) async {
    files[path] = content;
  }

  @override
  Future<void> deleteFile(String path) async {
    files.remove(path);
  }

  @override
  Future<AndroidCommandResult> runCommand(String command) async =>
      commandResult;
}

Future<AppViewModel> _createViewModel(_ControlledGateway gateway) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final viewModel = AppViewModel(
    repository: AgentRepository(
      gatewayFactories: <ProviderProtocol, AgentGatewayFactory>{
        ProviderProtocol.demo: () => gateway,
      },
    ),
    settingsStore: AppSettingsStore(secrets: _MemorySecretStore()),
  );
  await viewModel.initialize();
  return viewModel;
}

Future<AppViewModel> _createViewModelWithPreferences(
  _ControlledGateway gateway,
  SharedPreferencesAsync preferences,
) async {
  final viewModel = AppViewModel(
    repository: AgentRepository(
      gatewayFactories: <ProviderProtocol, AgentGatewayFactory>{
        ProviderProtocol.demo: () => gateway,
      },
    ),
    settingsStore: AppSettingsStore(
      preferences: preferences,
      secrets: _MemorySecretStore(),
    ),
  );
  await viewModel.initialize();
  return viewModel;
}

AgentMessage _lastAssistantMessage(AppViewModel viewModel, String sessionId) {
  final session = viewModel.state.sessions.firstWhere(
    (item) => item.id == sessionId,
  );
  return session.messages.lastWhere(
    (message) => message.role == MessageRole.assistant,
  );
}

void main() {
  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  test('keeps independent runs attached to their starting sessions', () async {
    final gateway = _ControlledGateway();
    final viewModel = await _createViewModel(gateway);
    addTearDown(viewModel.dispose);

    final firstId = viewModel.createSession();
    await viewModel.sendMessage('first task');
    final secondId = viewModel.createSession();
    await viewModel.sendMessage('second task');

    expect(gateway.runs, hasLength(2));
    expect(
      viewModel.state.sendingSessionIds,
      containsAll(<String>[firstId, secondId]),
    );

    gateway.runs[0].controller.add(const AgentTextDelta('first response'));
    gateway.runs[1].controller.add(const AgentTextDelta('second response'));
    await Future<void>.delayed(Duration.zero);

    expect(_lastAssistantMessage(viewModel, firstId).content, 'first response');
    expect(
      _lastAssistantMessage(viewModel, secondId).content,
      'second response',
    );
    expect(viewModel.state.isSending, isTrue);

    await gateway.runs[0].controller.close();
    await gateway.runs[1].controller.close();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.sendingSessionIds, isEmpty);
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == firstId)
          .status,
      SessionStatus.idle,
    );
  });

  test('scopes approval state to the session that produced it', () async {
    final gateway = _ControlledGateway();
    final viewModel = await _createViewModel(gateway);
    addTearDown(viewModel.dispose);

    final firstId = viewModel.createSession();
    await viewModel.sendMessage('inspect files');
    final request = ApprovalRequest(
      requestId: 42,
      kind: ApprovalKind.fileChange,
      title: 'Apply changes?',
    );
    gateway.runs.single.controller.add(AgentApprovalRequired(request));
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.approvalForSession(firstId), same(request));
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == firstId)
          .status,
      SessionStatus.waitingApproval,
    );

    final secondId = viewModel.createSession();
    expect(viewModel.state.pendingApproval, isNull);
    viewModel.selectSession(firstId);
    expect(viewModel.state.pendingApproval, same(request));

    await viewModel.resolveApproval(approve: true, allowForSession: false);
    expect(gateway.approvals, <ApprovalRequest>[request]);
    expect(viewModel.state.approvalForSession(firstId), isNull);
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == firstId)
          .status,
      SessionStatus.running,
    );
    expect(viewModel.state.sendingSessionIds, contains(firstId));
    expect(
      viewModel.state.sessions.any((session) => session.id == secondId),
      isTrue,
    );
  });

  test(
    'keeps later approval requests queued after resolving the first',
    () async {
      final gateway = _ControlledGateway();
      final viewModel = await _createViewModel(gateway);
      addTearDown(viewModel.dispose);

      final sessionId = viewModel.createSession();
      await viewModel.sendMessage('run two guarded actions');
      final first = ApprovalRequest(
        requestId: 101,
        kind: ApprovalKind.command,
        title: 'Run first command?',
      );
      final second = ApprovalRequest(
        requestId: 102,
        kind: ApprovalKind.fileChange,
        title: 'Apply file changes?',
      );
      gateway.runs.single.controller.add(AgentApprovalRequired(first));
      gateway.runs.single.controller.add(AgentApprovalRequired(second));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.approvalsForSession(sessionId), <ApprovalRequest>[
        first,
        second,
      ]);
      expect(viewModel.state.pendingApproval, same(first));

      await viewModel.resolveApproval(approve: true, allowForSession: false);
      expect(viewModel.state.approvalsForSession(sessionId), <ApprovalRequest>[
        second,
      ]);
      expect(viewModel.state.pendingApproval, same(second));
      expect(
        viewModel.state.sessions
            .firstWhere((session) => session.id == sessionId)
            .status,
        SessionStatus.waitingApproval,
      );
    },
  );

  test(
    'ignores duplicate approval taps while the first response is in flight',
    () async {
      final gateway = _ControlledGateway()..approvalGate = Completer<void>();
      final viewModel = await _createViewModel(gateway);
      addTearDown(viewModel.dispose);

      final sessionId = viewModel.createSession();
      await viewModel.sendMessage('approve once');
      final request = ApprovalRequest(
        requestId: 201,
        kind: ApprovalKind.command,
        title: 'Run command?',
      );
      gateway.runs.single.controller.add(AgentApprovalRequired(request));
      await Future<void>.delayed(Duration.zero);

      final first = viewModel.resolveApproval(
        approve: true,
        allowForSession: false,
      );
      final second = viewModel.resolveApproval(
        approve: true,
        allowForSession: false,
      );
      expect(viewModel.state.isResolvingApproval(sessionId), isTrue);
      gateway.approvalGate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(gateway.approvals, <ApprovalRequest>[request]);
      expect(viewModel.state.isResolvingApproval(sessionId), isFalse);
    },
  );

  test(
    'cancelling a run ignores late stream events and interrupts its gateway',
    () async {
      final gateway = _ControlledGateway();
      final viewModel = await _createViewModel(gateway);
      addTearDown(viewModel.dispose);

      final sessionId = viewModel.createSession();
      await viewModel.sendMessage('long running task');
      await viewModel.cancelRun(sessionId: sessionId);

      expect(gateway.interruptCount, 1);
      expect(viewModel.state.sendingSessionIds, isEmpty);
      expect(
        viewModel.state.sessions
            .firstWhere((session) => session.id == sessionId)
            .status,
        SessionStatus.idle,
      );

      gateway.runs.single.controller.add(const AgentTextDelta('late response'));
      await Future<void>.delayed(Duration.zero);
      expect(
        _lastAssistantMessage(viewModel, sessionId).content,
        'Run cancelled.',
      );
    },
  );

  test(
    'a normalized failure completes the run and surfaces on its task',
    () async {
      final gateway = _ControlledGateway();
      final viewModel = await _createViewModel(gateway);
      addTearDown(viewModel.dispose);

      final sessionId = viewModel.createSession();
      await viewModel.sendMessage('fail this task');
      gateway.runs.single.controller.add(const AgentFailure('gateway failed'));
      await Future<void>.delayed(Duration.zero);

      final session = viewModel.state.sessions.firstWhere(
        (item) => item.id == sessionId,
      );
      expect(session.status, SessionStatus.failed);
      expect(
        _lastAssistantMessage(viewModel, sessionId).status,
        MessageStatus.error,
      );
      expect(
        _lastAssistantMessage(viewModel, sessionId).content,
        'gateway failed',
      );
      expect(viewModel.state.isSending, isFalse);
      expect(viewModel.state.errorMessage, 'gateway failed');
    },
  );

  test('gateway setup failure leaves a retryable error message', () async {
    final gateway = _ControlledGateway()..throwOnStream = true;
    final viewModel = await _createViewModel(gateway);
    addTearDown(viewModel.dispose);

    final sessionId = viewModel.createSession();
    final sent = await viewModel.sendMessage('will fail to start');

    expect(sent, isFalse);
    expect(viewModel.state.sendingSessionIds, isEmpty);
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == sessionId)
          .status,
      SessionStatus.failed,
    );
    expect(
      _lastAssistantMessage(viewModel, sessionId).status,
      MessageStatus.error,
    );
    expect(
      _lastAssistantMessage(viewModel, sessionId).content,
      'Bad state: gateway setup failed',
    );
    gateway.throwOnStream = false;
    final retry = await viewModel.sendMessage('retry the task');
    expect(retry, isTrue);
    expect(viewModel.state.sendingSessionIds, contains(sessionId));
  });

  test('restores task history and the selected task after a restart', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = SharedPreferencesAsync();
    final firstGateway = _ControlledGateway();
    final first = await _createViewModelWithPreferences(
      firstGateway,
      preferences,
    );
    final sessionId = first.createSession(projectPath: '/tmp/project');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    first.dispose();

    final second = await _createViewModelWithPreferences(
      _ControlledGateway(),
      preferences,
    );
    addTearDown(second.dispose);

    expect(
      second.state.sessions.any((session) => session.id == sessionId),
      isTrue,
    );
    expect(second.state.selectedSessionId, sessionId);
    expect(second.state.selectedSession?.projectPath, '/tmp/project');
  });

  test(
    'does not let stale provider errors clear the active task error',
    () async {
      final gateway = _ControlledGateway()
        ..models = const <ModelInfo>[ModelInfo(id: 'm', displayName: 'M')];
      final viewModel = await _createViewModel(gateway);
      addTearDown(viewModel.dispose);

      final sessionId = viewModel.createSession();
      await viewModel.sendMessage('start a task');
      gateway.runs.single.controller.add(const AgentFailure('task failed'));
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.errorMessage, 'task failed');

      gateway.modelListGate = Completer<void>();
      final refresh = viewModel.refreshModels();
      gateway.modelListGate!.complete();
      await refresh;
      expect(viewModel.state.errorMessage, 'task failed');
      expect(
        viewModel.state.sessions
            .firstWhere((session) => session.id == sessionId)
            .messages,
        isNotEmpty,
      );
    },
  );

  test('migrates a removed custom provider to a safe task fallback', () async {
    final gateway = _ControlledGateway();
    final viewModel = await _createViewModel(gateway);
    addTearDown(viewModel.dispose);

    const custom = ProviderConfig(
      id: 'custom-provider',
      name: 'Custom',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'https://example.com/v1',
      model: 'custom-model',
    );
    await viewModel.addProvider(custom);
    final sessionId = viewModel.createSession(
      providerId: custom.id,
      projectPath: '/tmp/project',
    );
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == sessionId)
          .providerId,
      custom.id,
    );

    await viewModel.removeProvider(custom.id);
    final migrated = viewModel.state.sessions.firstWhere(
      (session) => session.id == sessionId,
    );
    expect(migrated.providerId, 'finn-demo');
    expect(migrated.model, 'custom-model');
  });

  test('changes the provider and model for one task only', () async {
    final gateway = _ControlledGateway();
    final viewModel = await _createViewModel(gateway);
    addTearDown(viewModel.dispose);

    final firstId = viewModel.createSession();
    final secondId = viewModel.createSession();

    await viewModel.setSessionProvider(
      firstId,
      'space-bunny-free',
      model: 'space-bunny-free',
    );

    final first = viewModel.state.sessions.firstWhere(
      (session) => session.id == firstId,
    );
    final second = viewModel.state.sessions.firstWhere(
      (session) => session.id == secondId,
    );
    expect(first.providerId, 'space-bunny-free');
    expect(first.model, 'space-bunny-free');
    expect(second.providerId, 'finn-demo');
  });

  test('keeps one active task available when task actions are used', () async {
    final gateway = _ControlledGateway();
    final viewModel = await _createViewModel(gateway);
    addTearDown(viewModel.dispose);

    final firstId = viewModel.createSession();
    final secondId = viewModel.createSession();
    viewModel.setSessionArchived(firstId, isArchived: true);
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == firstId)
          .isArchived,
      isTrue,
    );
    expect(viewModel.state.selectedSessionId, secondId);

    viewModel.setSessionArchived(secondId, isArchived: true);
    expect(
      viewModel.state.sessions
          .firstWhere((session) => session.id == secondId)
          .isArchived,
      isTrue,
    );
    expect(viewModel.state.selectedSession, isNotNull);
    expect(viewModel.state.selectedSession?.isArchived, isFalse);
  });

  test(
    'tracks workspace dirty state, saves, and reports command status',
    () async {
      final gateway = _ControlledGateway();
      final runtime = _WorkspaceRuntime();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final viewModel = AppViewModel(
        repository: AgentRepository(
          gatewayFactories: <ProviderProtocol, AgentGatewayFactory>{
            ProviderProtocol.demo: () => gateway,
          },
        ),
        settingsStore: AppSettingsStore(secrets: _MemorySecretStore()),
        runtimeBridge: runtime,
        probeAndroidRuntime: true,
      );
      await viewModel.initialize();
      addTearDown(viewModel.dispose);

      expect(viewModel.state.runtimeReady, isTrue);
      expect(viewModel.state.workspaceFiles, isNotEmpty);
      await viewModel.openWorkspaceFile('notes.txt');
      expect(viewModel.state.workspaceDirty, isFalse);

      viewModel.updateWorkspaceDraft('changed');
      expect(viewModel.state.workspaceDirty, isTrue);
      await viewModel.saveWorkspaceFile(
        path: 'notes.txt',
        content: viewModel.state.workspaceFileContent,
      );
      expect(runtime.files['notes.txt'], 'changed');
      expect(viewModel.state.workspaceDirty, isFalse);

      runtime.commandResult = const AndroidCommandResult(
        exitCode: 7,
        output: 'command failed',
      );
      await viewModel.runWorkspaceCommand('cat notes.txt');
      expect(viewModel.state.workspaceCommandExitCode, 7);
      expect(viewModel.state.workspaceCommandOutput, 'command failed');
    },
  );

  test('falls back to a welcome task when stored history is corrupt', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final preferences = SharedPreferencesAsync();
    await preferences.setString('sessions', '{not valid json');
    final viewModel = await _createViewModelWithPreferences(
      _ControlledGateway(),
      preferences,
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.state.sessions, hasLength(1));
    expect(viewModel.state.sessions.single.title, 'Welcome to Finn Code');
  });
}
