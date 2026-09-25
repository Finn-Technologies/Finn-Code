import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/agent_repository.dart';
import '../data/services/android_runtime_bridge.dart';
import '../data/storage/app_settings_store.dart';
import '../domain/models/agent_event.dart';
import '../domain/models/agent_message.dart';
import '../domain/models/agent_session.dart';
import '../domain/models/agent_stream_update.dart';
import '../domain/models/model_info.dart';
import '../domain/models/provider_config.dart';
import '../domain/models/workspace_file.dart';
import '../domain/services/agent_gateway.dart';

const Object _unset = Object();

class AppState {
  const AppState({
    this.isInitialized = false,
    this.navigationIndex = 0,
    this.themeMode = ThemeMode.system,
    this.providers = const <ProviderConfig>[],
    this.selectedProviderId = 'android-on-device',
    this.sessions = const <AgentSession>[],
    this.selectedSessionId,
    this.models = const <ModelInfo>[],
    this.sendingSessionIds = const <String>{},
    this.pendingApprovals = const <String, List<ApprovalRequest>>{},
    this.resolvingApprovalSessionIds = const <String>{},
    this.errorMessage,
    this.busyProviderIds = const <String>{},
    this.connectedProviderIds = const <String>{'android-on-device'},
    this.runtimeReady = false,
    this.runtimeName = 'Android runtime',
    this.runtimeWorkspace = 'On-device workspace',
    this.runtimePath = '',
    this.runtimeError,
    this.workspaceFiles = const <WorkspaceFile>[],
    this.workspaceCurrentPath = '.',
    this.selectedWorkspacePath,
    this.workspaceFileContent = '',
    this.workspaceSavedContent = '',
    this.workspaceDirty = false,
    this.workspaceBusy = false,
    this.workspaceCommandOutput = '',
    this.workspaceCommandExitCode,
  });

  final bool isInitialized;
  final int navigationIndex;
  final ThemeMode themeMode;
  final List<ProviderConfig> providers;
  final String selectedProviderId;
  final List<AgentSession> sessions;
  final String? selectedSessionId;
  final List<ModelInfo> models;
  final Set<String> sendingSessionIds;
  final Map<String, List<ApprovalRequest>> pendingApprovals;
  final Set<String> resolvingApprovalSessionIds;
  final String? errorMessage;
  final Set<String> busyProviderIds;
  final Set<String> connectedProviderIds;
  final bool runtimeReady;
  final String runtimeName;
  final String runtimeWorkspace;
  final String runtimePath;
  final String? runtimeError;
  final List<WorkspaceFile> workspaceFiles;
  final String workspaceCurrentPath;
  final String? selectedWorkspacePath;
  final String workspaceFileContent;
  final String workspaceSavedContent;
  final bool workspaceDirty;
  final bool workspaceBusy;
  final String workspaceCommandOutput;
  final int? workspaceCommandExitCode;

  String? get effectiveSelectedSessionId => selectedSession?.id;

  bool get isSending =>
      effectiveSelectedSessionId != null &&
      sendingSessionIds.contains(effectiveSelectedSessionId);

  ApprovalRequest? get pendingApproval {
    final sessionId = effectiveSelectedSessionId;
    if (sessionId == null) return null;
    final queue = pendingApprovals[sessionId];
    return queue == null || queue.isEmpty ? null : queue.first;
  }

  bool isSessionSending(String sessionId) =>
      sendingSessionIds.contains(sessionId);

  ApprovalRequest? approvalForSession(String sessionId) {
    final queue = pendingApprovals[sessionId];
    return queue == null || queue.isEmpty ? null : queue.first;
  }

  List<ApprovalRequest> approvalsForSession(String sessionId) =>
      List<ApprovalRequest>.unmodifiable(
        pendingApprovals[sessionId] ?? const <ApprovalRequest>[],
      );

  bool isResolvingApproval(String sessionId) =>
      resolvingApprovalSessionIds.contains(sessionId);

  ProviderConfig get selectedProvider => providers.firstWhere(
    (provider) => provider.id == selectedProviderId,
    orElse: () => ProviderConfig.presets.first,
  );

  AgentSession? get selectedSession {
    for (final session in sessions) {
      if (session.id == selectedSessionId && !session.isArchived) {
        return session;
      }
    }
    for (final session in sessions) {
      if (!session.isArchived) return session;
    }
    return null;
  }

  AppState copyWith({
    bool? isInitialized,
    int? navigationIndex,
    ThemeMode? themeMode,
    List<ProviderConfig>? providers,
    String? selectedProviderId,
    List<AgentSession>? sessions,
    Object? selectedSessionId = _unset,
    List<ModelInfo>? models,
    Set<String>? sendingSessionIds,
    Map<String, List<ApprovalRequest>>? pendingApprovals,
    Set<String>? resolvingApprovalSessionIds,
    Object? errorMessage = _unset,
    Set<String>? busyProviderIds,
    Set<String>? connectedProviderIds,
    bool? runtimeReady,
    String? runtimeName,
    String? runtimeWorkspace,
    String? runtimePath,
    Object? runtimeError = _unset,
    List<WorkspaceFile>? workspaceFiles,
    String? workspaceCurrentPath,
    Object? selectedWorkspacePath = _unset,
    String? workspaceFileContent,
    String? workspaceSavedContent,
    bool? workspaceDirty,
    bool? workspaceBusy,
    String? workspaceCommandOutput,
    Object? workspaceCommandExitCode = _unset,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      navigationIndex: navigationIndex ?? this.navigationIndex,
      themeMode: themeMode ?? this.themeMode,
      providers: providers ?? this.providers,
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      sessions: sessions ?? this.sessions,
      selectedSessionId: identical(selectedSessionId, _unset)
          ? this.selectedSessionId
          : selectedSessionId as String?,
      models: models ?? this.models,
      sendingSessionIds: sendingSessionIds ?? this.sendingSessionIds,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      resolvingApprovalSessionIds:
          resolvingApprovalSessionIds ?? this.resolvingApprovalSessionIds,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      busyProviderIds: busyProviderIds ?? this.busyProviderIds,
      connectedProviderIds: connectedProviderIds ?? this.connectedProviderIds,
      runtimeReady: runtimeReady ?? this.runtimeReady,
      runtimeName: runtimeName ?? this.runtimeName,
      runtimeWorkspace: runtimeWorkspace ?? this.runtimeWorkspace,
      runtimePath: runtimePath ?? this.runtimePath,
      runtimeError: identical(runtimeError, _unset)
          ? this.runtimeError
          : runtimeError as String?,
      workspaceFiles: workspaceFiles ?? this.workspaceFiles,
      workspaceCurrentPath: workspaceCurrentPath ?? this.workspaceCurrentPath,
      selectedWorkspacePath: identical(selectedWorkspacePath, _unset)
          ? this.selectedWorkspacePath
          : selectedWorkspacePath as String?,
      workspaceFileContent: workspaceFileContent ?? this.workspaceFileContent,
      workspaceSavedContent:
          workspaceSavedContent ?? this.workspaceSavedContent,
      workspaceDirty: workspaceDirty ?? this.workspaceDirty,
      workspaceBusy: workspaceBusy ?? this.workspaceBusy,
      workspaceCommandOutput:
          workspaceCommandOutput ?? this.workspaceCommandOutput,
      workspaceCommandExitCode: identical(workspaceCommandExitCode, _unset)
          ? this.workspaceCommandExitCode
          : workspaceCommandExitCode as int?,
    );
  }
}

class AppViewModel extends ChangeNotifier {
  AppViewModel({
    required AgentRepository repository,
    required AppSettingsStore settingsStore,
    AndroidRuntimeBridge? runtimeBridge,
    bool probeAndroidRuntime = false,
  }) : _repository = repository,
       _settingsStore = settingsStore,
       _runtimeBridge = runtimeBridge ?? AndroidRuntimeBridge(),
       _probeAndroidRuntime = probeAndroidRuntime;

  final AgentRepository _repository;
  final AppSettingsStore _settingsStore;
  final AndroidRuntimeBridge _runtimeBridge;
  final bool _probeAndroidRuntime;
  final Map<String, ProviderConfig> _providerOverrides =
      <String, ProviderConfig>{};
  final Map<String, List<ModelInfo>> _modelsByProvider =
      <String, List<ModelInfo>>{};
  final Map<String, _ActiveRun> _runs = <String, _ActiveRun>{};
  Timer? _sessionPersistDebounce;
  Future<void> _persistenceTail = Future<void>.value();
  String? _providerErrorMessage;
  bool _isDisposed = false;

  AppState _state = const AppState();
  AppState get state => _state;

  int _localId = 0;

  Future<void> initialize() async {
    late List<Object?> storedProviders;
    try {
      storedProviders = await Future.wait<Object?>(<Future<Object?>>[
        _settingsStore.customProviders(),
        _settingsStore.providerOverrides(),
        _settingsStore.selectedProviderId(),
        _settingsStore.themeMode(),
        _settingsStore.sessions(),
        _settingsStore.selectedSessionId(),
      ]);
    } on Object {
      storedProviders = const <Object?>[
        <ProviderConfig>[],
        <String, Map<String, dynamic>>{},
        null,
        'system',
        <AgentSession>[],
        null,
      ];
    }
    final customProviders = storedProviders[0] as List<ProviderConfig>;
    final overrides = storedProviders[1] as Map<String, Map<String, dynamic>>;
    final selectedId = storedProviders[2] as String?;
    final themeName = storedProviders[3] as String;
    final storedSessions = storedProviders[4] as List<AgentSession>;
    final selectedSessionId = storedProviders[5] as String?;
    _providerOverrides
      ..clear()
      ..addEntries(
        overrides.entries.map(
          (entry) =>
              MapEntry(entry.key, ProviderConfig.fromPersistedMap(entry.value)),
        ),
      );

    final providers = <ProviderConfig>[
      for (final preset in ProviderConfig.presets)
        _providerOverrides[preset.id] ?? preset,
      ...customProviders.where(
        (provider) =>
            !ProviderConfig.presets.any((preset) => preset.id == provider.id),
      ),
    ];
    List<String?> keys;
    try {
      keys = await Future.wait<String?>(
        providers.map((provider) => _settingsStore.apiKey(provider.id)),
      );
    } on Object {
      keys = List<String?>.filled(providers.length, null);
    }
    for (var index = 0; index < providers.length; index++) {
      providers[index] = providers[index].copyWith(apiKey: keys[index] ?? '');
    }

    final runtimeInfo = _probeAndroidRuntime
        ? await _runtimeBridge.getInfo()
        : null;
    final preferredId = runtimeInfo == null ? 'finn-demo' : 'android-on-device';
    final safeSelectedId =
        providers.any((provider) => provider.id == selectedId)
        ? selectedId!
        : providers.any((provider) => provider.id == preferredId)
        ? preferredId
        : providers.first.id;
    final selectedProvider = providers.firstWhere(
      (provider) => provider.id == safeSelectedId,
    );
    final sessions = storedSessions.isEmpty
        ? <AgentSession>[
            _welcomeSession(safeSelectedId, selectedProvider.model),
          ]
        : storedSessions
              .map(
                (session) => _restoreSession(
                  session,
                  providers: providers,
                  fallbackProvider: selectedProvider,
                ),
              )
              .whereType<AgentSession>()
              .toList(growable: false);
    final safeSessions = sessions.isEmpty
        ? <AgentSession>[
            _welcomeSession(safeSelectedId, selectedProvider.model),
          ]
        : sessions;
    final restoredSelectedId =
        safeSessions.any((session) => session.id == selectedSessionId)
        ? selectedSessionId!
        : safeSessions.first.id;

    _state = _state.copyWith(
      isInitialized: true,
      themeMode: _themeModeFromName(themeName),
      providers: List<ProviderConfig>.unmodifiable(providers),
      selectedProviderId: safeSelectedId,
      sessions: List<AgentSession>.unmodifiable(safeSessions),
      selectedSessionId: restoredSelectedId,
      connectedProviderIds: <String>{
        if (runtimeInfo != null) 'android-on-device',
      },
      runtimeReady: runtimeInfo != null,
      runtimeName: runtimeInfo?.platform ?? 'Android runtime',
      runtimeWorkspace: runtimeInfo?.workspaceName ?? 'On-device workspace',
      runtimePath: runtimeInfo?.workspacePath ?? '',
      runtimeError: runtimeInfo == null
          ? 'Android runtime bridge unavailable'
          : null,
    );
    notifyListeners();
    if (runtimeInfo != null) await refreshWorkspaceFiles();
    _queueSessionPersistence();
  }

  Future<void> refreshRuntime() async {
    final info = await _runtimeBridge.getInfo();
    if (info == null) {
      _state = _state.copyWith(
        runtimeReady: false,
        runtimeError: 'Android runtime bridge unavailable',
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      runtimeReady: true,
      runtimeName: info.platform,
      runtimeWorkspace: info.workspaceName,
      runtimePath: info.workspacePath,
      runtimeError: null,
    );
    notifyListeners();
    await refreshWorkspaceFiles(path: _state.workspaceCurrentPath);
  }

  Future<void> refreshWorkspaceFiles({String path = '.'}) async {
    if (!_state.runtimeReady || _state.workspaceBusy) return;
    _state = _state.copyWith(workspaceBusy: true);
    notifyListeners();
    try {
      final files = await _runtimeBridge.listFiles(path: path);
      _state = _state.copyWith(
        workspaceFiles: List<WorkspaceFile>.unmodifiable(
          files.map(WorkspaceFile.fromMap),
        ),
        workspaceCurrentPath: path,
        workspaceBusy: false,
        workspaceCommandExitCode: null,
      );
    } on Object catch (error) {
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: _friendlyError(error),
      );
    }
    notifyListeners();
  }

  Future<void> navigateWorkspaceUp() async {
    final current = _state.workspaceCurrentPath;
    if (current == '.') return;
    final separator = current.lastIndexOf('/');
    final parent = separator <= 0 ? '.' : current.substring(0, separator);
    await refreshWorkspaceFiles(path: parent);
  }

  Future<void> openWorkspaceFile(String path) async {
    if (!_state.runtimeReady || _state.workspaceBusy) return;
    _state = _state.copyWith(workspaceBusy: true);
    notifyListeners();
    try {
      final content = await _runtimeBridge.readFile(path);
      _state = _state.copyWith(
        selectedWorkspacePath: path,
        workspaceFileContent: content,
        workspaceSavedContent: content,
        workspaceDirty: false,
        workspaceBusy: false,
        workspaceCommandOutput: '',
      );
    } on Object catch (error) {
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: _friendlyError(error),
      );
    }
    notifyListeners();
  }

  Future<void> createWorkspaceFile() async {
    if (!_state.runtimeReady || _state.workspaceBusy) return;
    final name = 'untitled-${DateTime.now().millisecondsSinceEpoch}.txt';
    final path = _state.workspaceCurrentPath == '.'
        ? name
        : '${_state.workspaceCurrentPath}/$name';
    _state = _state.copyWith(workspaceBusy: true);
    notifyListeners();
    try {
      await _runtimeBridge.writeFile(path, '');
      _state = _state.copyWith(
        selectedWorkspacePath: path,
        workspaceFileContent: '',
        workspaceSavedContent: '',
        workspaceDirty: false,
        workspaceBusy: false,
        workspaceCommandOutput: 'Created on Android · $path',
      );
      await refreshWorkspaceFiles(path: _state.workspaceCurrentPath);
    } on Object catch (error) {
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: _friendlyError(error),
      );
      notifyListeners();
    }
  }

  Future<void> saveWorkspaceFile({
    required String path,
    required String content,
  }) async {
    if (!_state.runtimeReady || _state.workspaceBusy) return;
    _state = _state.copyWith(workspaceBusy: true);
    notifyListeners();
    try {
      await _runtimeBridge.writeFile(path, content);
      _state = _state.copyWith(
        workspaceFileContent: content,
        workspaceSavedContent: content,
        workspaceDirty: false,
        workspaceBusy: false,
        workspaceCommandOutput: 'Saved on Android · $path',
      );
      await refreshWorkspaceFiles(path: _state.workspaceCurrentPath);
    } on Object catch (error) {
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: _friendlyError(error),
      );
      notifyListeners();
    }
  }

  void updateWorkspaceDraft(String content) {
    if (content == _state.workspaceFileContent) return;
    _state = _state.copyWith(
      workspaceFileContent: content,
      workspaceDirty: content != _state.workspaceSavedContent,
    );
    notifyListeners();
  }

  void resetWorkspaceDraft() {
    if (!_state.workspaceDirty) return;
    _state = _state.copyWith(
      workspaceFileContent: _state.workspaceSavedContent,
      workspaceDirty: false,
    );
    notifyListeners();
  }

  void clearWorkspaceSelection() {
    if (_state.selectedWorkspacePath == null && !_state.workspaceDirty) return;
    _state = _state.copyWith(
      selectedWorkspacePath: null,
      workspaceFileContent: '',
      workspaceSavedContent: '',
      workspaceDirty: false,
    );
    notifyListeners();
  }

  void navigateWorkspaceToRoot() {
    if (_state.workspaceCurrentPath == '.') return;
    unawaited(refreshWorkspaceFiles(path: '.'));
  }

  Future<void> deleteWorkspaceFile(String path) async {
    if (!_state.runtimeReady || _state.workspaceBusy) return;
    _state = _state.copyWith(workspaceBusy: true);
    notifyListeners();
    try {
      await _runtimeBridge.deleteFile(path);
      final selectedPath = _state.selectedWorkspacePath == path
          ? null
          : _state.selectedWorkspacePath;
      _state = _state.copyWith(
        selectedWorkspacePath: selectedPath,
        workspaceFileContent: selectedPath == null
            ? ''
            : _state.workspaceFileContent,
        workspaceSavedContent: selectedPath == null
            ? ''
            : _state.workspaceSavedContent,
        workspaceDirty: false,
        workspaceBusy: false,
        workspaceCommandOutput: 'Deleted on Android · $path',
      );
      await refreshWorkspaceFiles(path: _state.workspaceCurrentPath);
    } on Object catch (error) {
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: _friendlyError(error),
      );
      notifyListeners();
    }
  }

  Future<void> runWorkspaceCommand(String command) async {
    final normalized = command.trim();
    if (!_state.runtimeReady || _state.workspaceBusy || normalized.isEmpty) {
      return;
    }
    _state = _state.copyWith(workspaceBusy: true);
    notifyListeners();
    try {
      final result = await _runtimeBridge.runCommand(normalized);
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: result.output.trim().isEmpty
            ? 'Exit code ${result.exitCode}'
            : result.output.trim(),
        workspaceCommandExitCode: result.exitCode,
      );
    } on Object catch (error) {
      _state = _state.copyWith(
        workspaceBusy: false,
        workspaceCommandOutput: _friendlyError(error),
        workspaceCommandExitCode: 1,
      );
    }
    notifyListeners();
  }

  AgentSession? _restoreSession(
    AgentSession session, {
    required List<ProviderConfig> providers,
    required ProviderConfig fallbackProvider,
  }) {
    ProviderConfig? provider;
    for (final candidate in providers) {
      if (candidate.id == session.providerId) {
        provider = candidate;
        break;
      }
    }
    provider ??= fallbackProvider;
    final status = switch (session.status) {
      SessionStatus.running ||
      SessionStatus.waitingApproval => SessionStatus.idle,
      _ => session.status,
    };
    final messages =
        status == SessionStatus.idle && session.status != SessionStatus.idle
        ? session.messages
              .map(
                (message) => message.status == MessageStatus.streaming
                    ? message.copyWith(
                        status: MessageStatus.complete,
                        content: message.content.isEmpty
                            ? 'The previous run was interrupted.'
                            : message.content,
                      )
                    : message,
              )
              .toList(growable: false)
        : session.messages;
    final model = session.model.isNotEmpty
        ? session.model
        : provider.model.isNotEmpty
        ? provider.model
        : 'finn-demo-v1';
    return session.copyWith(
      providerId: provider.id,
      model: model,
      status: status,
      messages: messages,
    );
  }

  AgentSession _welcomeSession(String providerId, String model) {
    final now = DateTime.now();
    return AgentSession(
      id: _newId('session'),
      title: 'Welcome to Finn Code',
      preview: 'Connect a provider or explore the offline agent tour.',
      providerId: providerId,
      model: model.isEmpty ? 'finn-demo-v1' : model,
      createdAt: now,
      updatedAt: now,
      isPinned: true,
      messages: <AgentMessage>[
        AgentMessage(
          id: _newId('message'),
          role: MessageRole.assistant,
          createdAt: now,
          content:
              'Welcome. Finn Code is your mobile control plane for coding agents. Start with the offline demo, connect a free API, or point the app at a Codex app-server for real tools and file changes.',
        ),
      ],
    );
  }

  ProviderConfig? providersForId(String id) {
    for (final provider in _state.providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  ThemeMode _themeModeFromName(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  String _themeModeName(ThemeMode value) => switch (value) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_localId++}';

  void selectNavigation(int index) {
    _state = _state.copyWith(navigationIndex: index, errorMessage: null);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _state = _state.copyWith(themeMode: value);
    notifyListeners();
    await _settingsStore.setThemeMode(_themeModeName(value));
  }

  void selectSession(String id) {
    if (!_state.sessions.any((session) => session.id == id)) return;
    _state = _state.copyWith(selectedSessionId: id, errorMessage: null);
    notifyListeners();
    _queueSessionPersistence();
  }

  void setSessionPinned(String id, {required bool isPinned}) {
    final current = _sessionById(id);
    if (current == null || current.isPinned == isPinned) return;
    _replaceSession(
      current.copyWith(isPinned: isPinned, updatedAt: DateTime.now()),
    );
    notifyListeners();
  }

  void setSessionArchived(String id, {required bool isArchived}) {
    final current = _sessionById(id);
    if (current == null || current.isArchived == isArchived) return;
    final otherActiveTasks = _state.sessions
        .where((session) => session.id != id && !session.isArchived)
        .length;
    if (isArchived && otherActiveTasks == 0) return;
    if (isArchived && _runs.containsKey(id)) {
      unawaited(cancelRun(sessionId: id));
    }
    final sessions = _state.sessions
        .map(
          (session) => session.id == id
              ? session.copyWith(
                  isArchived: isArchived,
                  updatedAt: DateTime.now(),
                )
              : session,
        )
        .toList(growable: false);
    AgentSession? nextSelected;
    if (_state.selectedSessionId == id) {
      for (final session in sessions) {
        if (!session.isArchived) {
          nextSelected = session;
          break;
        }
      }
    }
    _state = _state.copyWith(
      sessions: List<AgentSession>.unmodifiable(sessions),
      selectedSessionId: _state.selectedSessionId == id
          ? nextSelected?.id
          : _state.selectedSessionId,
    );
    notifyListeners();
    _queueSessionPersistence();
  }

  Future<void> retrySelectedSession() async {
    final session = _state.selectedSession;
    if (session == null) return;
    AgentMessage? lastFailed;
    for (final message in session.messages.reversed) {
      if (message.role == MessageRole.user &&
          message.content.trim().isNotEmpty) {
        lastFailed = message;
        break;
      }
    }
    if (lastFailed == null) return;
    await sendMessage(lastFailed.content, sessionId: session.id);
  }

  String createSession({String? providerId, String projectPath = ''}) {
    final provider =
        providersForId(providerId ?? _state.selectedProviderId) ??
        _state.selectedProvider;
    final now = DateTime.now();
    final session = AgentSession(
      id: _newId('session'),
      title: 'New coding task',
      preview: 'Ready for a new request.',
      providerId: provider.id,
      model: provider.model,
      projectPath: projectPath,
      createdAt: now,
      updatedAt: now,
    );
    _state = _state.copyWith(
      sessions: List<AgentSession>.unmodifiable(<AgentSession>[
        session,
        ..._state.sessions,
      ]),
      selectedSessionId: session.id,
      errorMessage: null,
    );
    notifyListeners();
    _queueSessionPersistence();
    return session.id;
  }

  void deleteSession(String id) {
    if (_state.sessions.length <= 1) return;
    if (_runs.containsKey(id)) {
      unawaited(cancelRun(sessionId: id));
    }
    final sessions = _state.sessions
        .where((session) => session.id != id)
        .toList();
    _state = _state.copyWith(
      sessions: List<AgentSession>.unmodifiable(sessions),
      selectedSessionId: sessions.first.id,
    );
    notifyListeners();
    _queueSessionPersistence();
  }

  Future<void> selectProvider(String id) async {
    if (!_state.providers.any((provider) => provider.id == id)) return;
    _state = _state.copyWith(
      selectedProviderId: id,
      models: _modelsByProvider[id] ?? const <ModelInfo>[],
      errorMessage: null,
    );
    notifyListeners();
    await _settingsStore.setSelectedProviderId(id);
  }

  Future<void> setSessionProvider(
    String sessionId,
    String providerId, {
    String? model,
  }) async {
    final session = _sessionById(sessionId);
    final provider = providersForId(providerId);
    if (session == null || provider == null) return;
    final nextModel = model?.trim().isNotEmpty == true
        ? model!.trim()
        : provider.model.isNotEmpty
        ? provider.model
        : session.model;
    _replaceSession(
      session.copyWith(
        providerId: provider.id,
        model: nextModel,
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateProvider(ProviderConfig provider) async {
    if (!_state.providers.any((item) => item.id == provider.id)) {
      _state = _state.copyWith(errorMessage: 'That provider no longer exists.');
      notifyListeners();
      return;
    }
    final providers = _state.providers
        .map((item) => item.id == provider.id ? provider : item)
        .toList(growable: false);
    _state = _state.copyWith(
      providers: List<ProviderConfig>.unmodifiable(providers),
      models: _state.selectedProviderId == provider.id
          ? const <ModelInfo>[]
          : _state.models,
      errorMessage: null,
    );
    notifyListeners();

    if (provider.isBuiltIn) {
      _providerOverrides[provider.id] = provider.copyWith(apiKey: '');
      await _settingsStore.setProviderOverrides(_providerOverrides);
    } else {
      final custom = providers.where((item) => !item.isBuiltIn).toList();
      await _settingsStore.setCustomProviders(custom);
    }
    await _settingsStore.setApiKey(provider.id, provider.apiKey);
    _modelsByProvider.remove(provider.id);
  }

  Future<void> addProvider(ProviderConfig provider) async {
    if (_state.providers.any((item) => item.id == provider.id)) {
      _state = _state.copyWith(
        errorMessage: 'A provider with that id already exists.',
      );
      notifyListeners();
      return;
    }
    final providers = <ProviderConfig>[..._state.providers, provider];
    _state = _state.copyWith(
      providers: List<ProviderConfig>.unmodifiable(providers),
      selectedProviderId: provider.id,
    );
    notifyListeners();
    await _settingsStore.setCustomProviders(
      providers.where((item) => !item.isBuiltIn).toList(),
    );
    await _settingsStore.setApiKey(provider.id, provider.apiKey);
    await _settingsStore.setSelectedProviderId(provider.id);
  }

  Future<void> removeProvider(String id) async {
    final provider = providersForId(id);
    if (provider == null || provider.isBuiltIn) return;
    if (_state.providers.length <= 1) return;
    final providers = _state.providers
        .where((item) => item.id != id)
        .toList(growable: false);
    final fallback = providers.firstWhere(
      (item) => item.id == _state.selectedProviderId,
      orElse: () => providers.first,
    );
    final selectedId = _state.selectedProviderId == id
        ? fallback.id
        : _state.selectedProviderId;
    final sessions = _state.sessions
        .map(
          (session) => session.providerId == id
              ? session.copyWith(
                  providerId: fallback.id,
                  model: session.model.isEmpty ? fallback.model : session.model,
                )
              : session,
        )
        .toList(growable: false);
    for (final session in _state.sessions) {
      if (session.providerId == id && _runs.containsKey(session.id)) {
        unawaited(cancelRun(sessionId: session.id));
      }
    }
    final connectedProviderIds = <String>{
      ..._state.connectedProviderIds.where(
        (item) =>
            item != id && providers.any((provider) => provider.id == item),
      ),
    };
    _state = _state.copyWith(
      providers: List<ProviderConfig>.unmodifiable(providers),
      sessions: List<AgentSession>.unmodifiable(sessions),
      selectedProviderId: selectedId,
      models: _modelsByProvider[selectedId] ?? const <ModelInfo>[],
      connectedProviderIds: connectedProviderIds,
    );
    notifyListeners();
    await _settingsStore.setCustomProviders(
      providers.where((item) => !item.isBuiltIn).toList(),
    );
    await _settingsStore.setApiKey(id, '');
    _queueSessionPersistence();
  }

  Future<void> refreshModels({bool showSuccess = false}) async {
    final provider = _state.selectedProvider;
    if (_state.busyProviderIds.contains(provider.id)) return;
    if (provider.requiresApiKey && provider.apiKey.isEmpty) {
      _providerErrorMessage = 'Add an API key for ${provider.name} first.';
      _state = _state.copyWith(errorMessage: _providerErrorMessage);
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      busyProviderIds: <String>{..._state.busyProviderIds, provider.id},
    );
    notifyListeners();
    AgentGateway? gateway;
    try {
      gateway = _repository.createGatewayFor(provider);
      final models = await gateway.listModels(provider);
      _modelsByProvider[provider.id] = models;
      final isStillSelected = _state.selectedProviderId == provider.id;
      _state = _state.copyWith(
        models: isStillSelected
            ? List<ModelInfo>.unmodifiable(models)
            : _state.models,
        busyProviderIds: <String>{..._state.busyProviderIds}
          ..remove(provider.id),
        connectedProviderIds: <String>{
          ..._state.connectedProviderIds.where(
            (id) => _state.providers.any((item) => item.id == id),
          ),
          provider.id,
        },
        errorMessage:
            isStillSelected &&
                _providerErrorMessage != null &&
                _state.errorMessage == _providerErrorMessage
            ? null
            : _state.errorMessage,
      );
      if (_state.errorMessage == null) _providerErrorMessage = null;
      notifyListeners();
    } on Object catch (error) {
      final isStillSelected = _state.selectedProviderId == provider.id;
      final message = _friendlyError(error);
      if (isStillSelected) _providerErrorMessage = message;
      _state = _state.copyWith(
        busyProviderIds: <String>{..._state.busyProviderIds}
          ..remove(provider.id),
        errorMessage: isStillSelected ? message : _state.errorMessage,
      );
      notifyListeners();
    } finally {
      if (gateway != null) {
        unawaited(_repository.releaseGateway(gateway));
      }
    }
  }

  Future<void> testProvider(String id) async {
    final provider = providersForId(id);
    if (provider == null) return;
    if (_state.busyProviderIds.contains(id)) return;
    if (provider.requiresApiKey && provider.apiKey.isEmpty) {
      _providerErrorMessage = 'Add an API key first.';
      _state = _state.copyWith(errorMessage: _providerErrorMessage);
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      busyProviderIds: <String>{..._state.busyProviderIds, id},
      errorMessage: _state.errorMessage == _providerErrorMessage
          ? null
          : _state.errorMessage,
    );
    if (_state.errorMessage == null) _providerErrorMessage = null;
    notifyListeners();
    AgentGateway? gateway;
    try {
      gateway = _repository.createGatewayFor(provider);
      await gateway.testConnection(provider);
      _state = _state.copyWith(
        busyProviderIds: <String>{..._state.busyProviderIds}..remove(id),
        connectedProviderIds: <String>{
          ..._state.connectedProviderIds.where(
            (item) => _state.providers.any((provider) => provider.id == item),
          ),
          id,
        },
        errorMessage: _state.errorMessage == _providerErrorMessage
            ? null
            : _state.errorMessage,
      );
      if (_state.errorMessage == null) _providerErrorMessage = null;
      notifyListeners();
    } on Object catch (error) {
      final message = _friendlyError(error);
      _providerErrorMessage = message;
      _state = _state.copyWith(
        busyProviderIds: <String>{..._state.busyProviderIds}..remove(id),
        errorMessage: message,
      );
      notifyListeners();
    } finally {
      if (gateway != null) {
        unawaited(_repository.releaseGateway(gateway));
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ') ? message.substring(11) : message;
  }

  Future<bool> sendMessage(String rawPrompt, {String? sessionId}) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty) return false;
    var session = sessionId == null
        ? _state.selectedSession
        : _sessionById(sessionId);
    if (session == null) {
      createSession();
      session = _state.selectedSession;
    }
    if (session == null) return false;
    if (_runs.containsKey(session.id) ||
        session.status == SessionStatus.running ||
        session.status == SessionStatus.waitingApproval) {
      return false;
    }
    final provider =
        providersForId(session.providerId) ?? _state.selectedProvider;
    if (provider.requiresApiKey && provider.apiKey.isEmpty) {
      _state = _state.copyWith(
        errorMessage: 'Add an API key for ${provider.name} before sending.',
      );
      notifyListeners();
      return false;
    }

    final now = DateTime.now();
    final userMessage = AgentMessage(
      id: _newId('message'),
      role: MessageRole.user,
      content: prompt,
      createdAt: now,
    );
    final assistantMessage = AgentMessage(
      id: _newId('message'),
      role: MessageRole.assistant,
      content: '',
      createdAt: now,
      status: MessageStatus.streaming,
    );
    final title = session.title == 'New coding task'
        ? _titleFromPrompt(prompt)
        : session.title;
    final updatedSession = session.copyWith(
      title: title,
      preview: prompt,
      updatedAt: now,
      status: SessionStatus.running,
      messages: <AgentMessage>[
        ...session.messages,
        userMessage,
        assistantMessage,
      ],
    );
    _replaceSession(updatedSession);
    _state = _state.copyWith(
      sendingSessionIds: <String>{
        ..._state.sendingSessionIds,
        updatedSession.id,
      },
      errorMessage: null,
    );
    notifyListeners();

    AgentGateway? gateway;
    try {
      gateway = _repository.createGatewayFor(provider);
      final run = _ActiveRun(
        sessionId: updatedSession.id,
        session: updatedSession,
        provider: provider,
        gateway: gateway,
      );
      _runs[updatedSession.id] = run;
      run.subscription = gateway
          .streamReply(
            session: updatedSession.copyWith(messages: session.messages),
            prompt: prompt,
            provider: provider,
          )
          .listen(
            (update) => _applyStreamUpdate(run, update),
            onError: (Object error) => _finishRunWithError(run, error),
            onDone: () => _finishRun(run),
            cancelOnError: false,
          );
      return true;
    } on Object catch (error) {
      _runs.remove(updatedSession.id);
      if (gateway != null) {
        unawaited(_repository.releaseGateway(gateway));
      }
      final current = _sessionById(updatedSession.id);
      if (current != null) {
        final messages = List<AgentMessage>.from(current.messages);
        if (messages.isNotEmpty) {
          final last = messages.length - 1;
          messages[last] = messages[last].copyWith(
            status: MessageStatus.error,
            content: messages[last].content.isEmpty
                ? _friendlyError(error)
                : messages[last].content,
          );
        }
        _replaceSession(
          current.copyWith(
            status: SessionStatus.failed,
            messages: messages,
            updatedAt: DateTime.now(),
          ),
        );
      }
      _state = _state.copyWith(
        sendingSessionIds: <String>{..._state.sendingSessionIds}
          ..remove(updatedSession.id),
        errorMessage: _friendlyError(error),
      );
      notifyListeners();
      return false;
    }
  }

  String _titleFromPrompt(String prompt) {
    final oneLine = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 46 ? oneLine : '${oneLine.substring(0, 43)}…';
  }

  void _applyStreamUpdate(_ActiveRun run, AgentStreamUpdate update) {
    if (!identical(_runs[run.sessionId], run)) return;
    final session = _sessionById(run.sessionId);
    if (session == null) return;
    final messages = List<AgentMessage>.from(session.messages);
    if (messages.isEmpty) return;
    final index = messages.length - 1;
    final message = messages[index];

    switch (update) {
      case AgentTextDelta(:final delta, :final isFinalAnswer):
        messages[index] = message.copyWith(
          content: message.content + delta,
          isFinalAnswer: isFinalAnswer,
        );
      case AgentReasoningDelta(:final delta):
        messages[index] = message.copyWith(
          reasoning: message.reasoning + delta,
        );
      case AgentEventUpdate(:final event):
        final events = List<AgentEvent>.from(message.events);
        final eventIndex = events.indexWhere((item) => item.id == event.id);
        if (eventIndex == -1) {
          events.add(event);
        } else {
          events[eventIndex] = event;
        }
        messages[index] = message.copyWith(events: events);
      case AgentRemoteThread(:final threadId):
        _replaceSession(session.copyWith(remoteThreadId: threadId));
        return;
      case AgentTurnComplete(:final inputTokens, :final outputTokens):
        final usage = <String, String>{
          if (inputTokens != null) 'Input': '$inputTokens tokens',
          if (outputTokens != null) 'Output': '$outputTokens tokens',
        };
        if (usage.isNotEmpty) {
          final events = List<AgentEvent>.from(message.events)
            ..add(
              AgentEvent(
                id: 'usage-${message.id}',
                kind: AgentEventKind.status,
                title: 'Usage',
                detail: usage.entries
                    .map((e) => '${e.key} ${e.value}')
                    .join(' · '),
                status: AgentEventStatus.completed,
              ),
            );
          messages[index] = message.copyWith(events: events);
        }
      case AgentFailure failure:
        messages[index] = message.copyWith(
          status: MessageStatus.error,
          content: message.content.isEmpty ? failure.message : message.content,
        );
        _replaceSession(
          session.copyWith(
            status: SessionStatus.failed,
            messages: messages,
            updatedAt: DateTime.now(),
          ),
        );
        _runs.remove(run.sessionId);
        unawaited(_repository.releaseGateway(run.gateway));
        _state = _state.copyWith(
          sendingSessionIds: <String>{..._state.sendingSessionIds}
            ..remove(run.sessionId),
          pendingApprovals: <String, List<ApprovalRequest>>{
            ..._state.pendingApprovals,
          }..remove(run.sessionId),
          errorMessage: _state.selectedSession?.id == run.sessionId
              ? failure.message
              : _state.errorMessage,
        );
        notifyListeners();
        return;
      case AgentApprovalRequired(:final request):
        _replaceSession(
          session.copyWith(
            status: SessionStatus.waitingApproval,
            messages: messages,
          ),
        );
        _state = _state.copyWith(
          pendingApprovals: <String, List<ApprovalRequest>>{
            ..._state.pendingApprovals,
            run.sessionId: <ApprovalRequest>[
              ...?_state.pendingApprovals[run.sessionId],
              request,
            ],
          },
        );
        notifyListeners();
        return;
    }
    _replaceSession(
      session.copyWith(messages: messages, updatedAt: DateTime.now()),
    );
    notifyListeners();
  }

  AgentSession? _sessionById(String id) {
    for (final session in _state.sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  void _replaceSession(AgentSession session) {
    final sessions = _state.sessions
        .map((item) => item.id == session.id ? session : item)
        .toList(growable: false);
    _state = _state.copyWith(
      sessions: List<AgentSession>.unmodifiable(sessions),
    );
    _queueSessionPersistence();
  }

  Map<String, List<ApprovalRequest>> _withoutResolvedApproval(
    String sessionId,
    ApprovalRequest resolvedRequest,
  ) {
    final queue = <ApprovalRequest>[...?_state.pendingApprovals[sessionId]];
    final index = queue.indexWhere(
      (request) => request.requestId == resolvedRequest.requestId,
    );
    if (index != -1) queue.removeAt(index);
    if (queue.isEmpty) {
      return <String, List<ApprovalRequest>>{..._state.pendingApprovals}
        ..remove(sessionId);
    }
    return <String, List<ApprovalRequest>>{
      ..._state.pendingApprovals,
      sessionId: List<ApprovalRequest>.unmodifiable(queue),
    };
  }

  void _queueSessionPersistence() {
    if (_isDisposed) return;
    _sessionPersistDebounce?.cancel();
    _sessionPersistDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistSessions());
    });
  }

  Future<void> flushSessionPersistence() async {
    if (_isDisposed) return;
    _sessionPersistDebounce?.cancel();
    await _persistSessions();
  }

  Future<void> _persistSessions() async {
    if (_isDisposed) return;
    final sessions = _state.sessions;
    final selectedSessionId = _state.selectedSession?.id;
    final operation = _persistenceTail.then(
      (_) => _writeSessions(sessions, selectedSessionId),
    );
    _persistenceTail = operation;
    await operation;
  }

  Future<void> _writeSessions(
    List<AgentSession> sessions,
    String? selectedSessionId,
  ) async {
    try {
      await _settingsStore.setSessions(sessions);
      if (selectedSessionId != null) {
        await _settingsStore.setSelectedSessionId(selectedSessionId);
      }
    } on Object {
      // Persistence is best effort; the in-memory harness remains usable if the
      // platform storage layer is temporarily unavailable.
    }
  }

  void _finishRun(_ActiveRun run) {
    if (!identical(_runs[run.sessionId], run)) return;
    final session = _sessionById(run.sessionId);
    if (session != null &&
        (session.status == SessionStatus.running ||
            session.status == SessionStatus.waitingApproval)) {
      final messages = List<AgentMessage>.from(session.messages);
      if (messages.isNotEmpty &&
          messages.last.status == MessageStatus.streaming) {
        messages[messages.length - 1] = messages.last.copyWith(
          status: MessageStatus.complete,
          content: messages.last.content.isEmpty
              ? 'The run ended without a final response.'
              : messages.last.content,
        );
      }
      _replaceSession(
        session.copyWith(
          status: SessionStatus.idle,
          messages: messages,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _runs.remove(run.sessionId);
    unawaited(_repository.releaseGateway(run.gateway));
    _state = _state.copyWith(
      sendingSessionIds: <String>{..._state.sendingSessionIds}
        ..remove(run.sessionId),
      pendingApprovals: <String, List<ApprovalRequest>>{
        ..._state.pendingApprovals,
      }..remove(run.sessionId),
    );
    notifyListeners();
  }

  void _finishRunWithError(_ActiveRun run, Object error) {
    if (!identical(_runs[run.sessionId], run)) return;
    final session = _sessionById(run.sessionId);
    if (session != null) {
      final messages = List<AgentMessage>.from(session.messages);
      if (messages.isNotEmpty) {
        messages[messages.length - 1] = messages.last.copyWith(
          status: MessageStatus.error,
        );
      }
      _replaceSession(
        session.copyWith(
          status: SessionStatus.failed,
          messages: messages,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _runs.remove(run.sessionId);
    unawaited(_repository.releaseGateway(run.gateway));
    _state = _state.copyWith(
      sendingSessionIds: <String>{..._state.sendingSessionIds}
        ..remove(run.sessionId),
      pendingApprovals: <String, List<ApprovalRequest>>{
        ..._state.pendingApprovals,
      }..remove(run.sessionId),
      errorMessage: _friendlyError(error),
    );
    notifyListeners();
  }

  Future<void> resolveApproval({
    required bool approve,
    required bool allowForSession,
  }) async {
    final session = _state.selectedSession;
    if (session == null) return;
    if (_state.isResolvingApproval(session.id)) return;
    final run = _runs[session.id];
    final request = run == null ? null : _state.approvalForSession(session.id);
    if (run == null || request == null) return;
    _state = _state.copyWith(
      resolvingApprovalSessionIds: <String>{
        ..._state.resolvingApprovalSessionIds,
        session.id,
      },
    );
    notifyListeners();
    try {
      await run.gateway.respondToApproval(
        provider: run.provider,
        request: request,
        approve: approve,
        allowForSession: allowForSession,
      );
      if (!identical(_runs[session.id], run)) return;
      final pendingApprovals = _withoutResolvedApproval(session.id, request);
      _state = _state.copyWith(
        pendingApprovals: pendingApprovals,
        resolvingApprovalSessionIds: <String>{
          ..._state.resolvingApprovalSessionIds,
        }..remove(session.id),
        errorMessage: _providerErrorMessage,
      );
      final current = _sessionById(session.id);
      if (current == null) return;
      _replaceSession(
        current.copyWith(
          status: pendingApprovals[session.id]?.isNotEmpty ?? false
              ? SessionStatus.waitingApproval
              : SessionStatus.running,
          updatedAt: DateTime.now(),
        ),
      );
      notifyListeners();
    } on Object catch (error) {
      if (!identical(_runs[session.id], run)) return;
      _state = _state.copyWith(
        resolvingApprovalSessionIds: <String>{
          ..._state.resolvingApprovalSessionIds,
        }..remove(session.id),
        errorMessage: _friendlyError(error),
      );
      notifyListeners();
    } finally {
      if (_state.isResolvingApproval(session.id)) {
        _state = _state.copyWith(
          resolvingApprovalSessionIds: <String>{
            ..._state.resolvingApprovalSessionIds,
          }..remove(session.id),
        );
        notifyListeners();
      }
    }
  }

  Future<void> cancelRun({String? sessionId}) async {
    final targetId = sessionId ?? _state.selectedSession?.id;
    if (targetId == null) return;
    final run = _runs[targetId];
    if (run == null) return;
    _runs.remove(targetId);
    await run.subscription?.cancel();
    final session = _sessionById(targetId) ?? run.session;
    try {
      await run.gateway.interrupt(session: session, provider: run.provider);
    } on Object {
      // The local stream is still cancelled even if the remote runtime cannot
      // be interrupted.
    }
    await _repository.releaseGateway(run.gateway);
    final currentSession = _sessionById(targetId);
    if (currentSession != null) {
      final messages = List<AgentMessage>.from(currentSession.messages);
      if (messages.isNotEmpty &&
          messages.last.status == MessageStatus.streaming) {
        messages[messages.length - 1] = messages.last.copyWith(
          status: MessageStatus.complete,
          content: messages.last.content.isEmpty
              ? 'Run cancelled.'
              : messages.last.content,
        );
      }
      _replaceSession(
        currentSession.copyWith(
          status: SessionStatus.idle,
          messages: messages,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _state = _state.copyWith(
      sendingSessionIds: <String>{..._state.sendingSessionIds}
        ..remove(targetId),
      pendingApprovals: <String, List<ApprovalRequest>>{
        ..._state.pendingApprovals,
      }..remove(targetId),
    );
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    _providerErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionPersistDebounce?.cancel();
    for (final run in _runs.values) {
      unawaited(run.subscription?.cancel());
    }
    _runs.clear();
    unawaited(_repository.dispose());
    super.dispose();
  }
}

class _ActiveRun {
  _ActiveRun({
    required this.sessionId,
    required this.session,
    required this.provider,
    required this.gateway,
  });

  final String sessionId;
  final AgentSession session;
  final ProviderConfig provider;
  final AgentGateway gateway;
  StreamSubscription<AgentStreamUpdate>? subscription;
}
