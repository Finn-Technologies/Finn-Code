import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_session.dart';
import '../../domain/models/agent_stream_update.dart';
import '../../domain/models/model_info.dart';
import '../../domain/models/provider_config.dart';
import '../../domain/services/agent_gateway.dart';
import 'android_runtime_bridge.dart';
import 'demo_agent_gateway.dart';
import 'openai_compatible_gateway.dart';
import 'sse.dart';

class OnDeviceAgentGateway implements AgentGateway {
  OnDeviceAgentGateway({
    AndroidRuntimeBridge? runtimeBridge,
    AgentGateway? modelGateway,
  }) : _runtimeBridge = runtimeBridge ?? AndroidRuntimeBridge(),
       _modelGateway = modelGateway ?? OpenAiCompatibleGateway();

  final AndroidRuntimeBridge _runtimeBridge;
  final AgentGateway _modelGateway;
  late final AgentGateway _fallbackGateway = DemoAgentGateway();
  bool _cancelled = false;
  final List<Map<String, String>> _toolMessages = <Map<String, String>>[];
  String? _lastCommandOutput;
  String? _lastCommand;
  AndroidRuntimeInfo? _runtimeInfo;

  AndroidRuntimeInfo? get runtimeInfo => _runtimeInfo;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) async* {
    _cancelled = false;
    _lastCommand = null;
    _lastCommandOutput = null;
    final info = await _runtimeBridge.getInfo();
    _runtimeInfo = info;
    yield AgentEventUpdate(
      AgentEvent(
        id: 'android-runtime',
        kind: AgentEventKind.status,
        title: info == null
            ? 'Android runtime fallback'
            : 'Android runtime ready',
        detail: info == null
            ? 'The platform bridge is unavailable; model transport is still active.'
            : '${info.platform} · ${info.workspaceName}',
        status: AgentEventStatus.completed,
      ),
    );

    _toolMessages
      ..clear()
      ..addAll(<Map<String, String>>[
        <String, String>{'role': 'user', 'content': prompt},
      ]);
    final localCommand = _extractLocalCommand(prompt);
    if (localCommand != null && !_cancelled) {
      yield* _runLocalCommand(localCommand);
      _toolMessages.add(<String, String>{
        'role': 'assistant',
        'content': 'The requested Android command was executed locally.',
      });
      _toolMessages.add(<String, String>{
        'role': 'user',
        'content': 'Android tool result:\n${_lastCommandOutput ?? ''}',
      });
    }

    for (var iteration = 0; iteration < 4 && !_cancelled; iteration++) {
      final modelGateway = info == null ? _fallbackGateway : _modelGateway;
      final updates = modelGateway.streamReply(
        session: session,
        prompt: _modelPrompt(prompt),
        provider: provider.copyWith(
          id: 'android-on-device-transport',
          protocol: ProviderProtocol.openAICompatible,
        ),
      );
      final response = StringBuffer();
      AgentTurnComplete? usage;
      await for (final update in updates) {
        if (_cancelled) return;
        if (update is AgentTextDelta) {
          response.write(update.delta);
          continue;
        }
        if (update is AgentTurnComplete) {
          usage = update;
          continue;
        }
        yield update;
      }
      final modelText = response.toString().trim();
      if (modelText.isEmpty) {
        final fallback = _toolResultText();
        if (fallback.isNotEmpty) yield AgentTextDelta(fallback);
        if (usage != null) yield usage;
        return;
      }
      final requestedCommand = _extractModelCommand(modelText);
      if (requestedCommand == null) {
        yield AgentTextDelta(modelText);
        if (usage != null) yield usage;
        return;
      }
      // A tool request is an internal protocol turn. Do not leak any prose
      // that happened to accompany the tag; the next model turn is the
      // user-facing answer after the device has executed the command.
      if (requestedCommand == _lastCommand) {
        final visibleText = _withoutModelCommand(modelText);
        if (visibleText.isNotEmpty) yield AgentTextDelta(visibleText);
        final fallback = _toolResultText();
        if (visibleText.isEmpty && fallback.isNotEmpty) {
          yield AgentTextDelta(fallback);
        }
        if (usage != null) yield usage;
        return;
      }
      _toolMessages.add(<String, String>{
        'role': 'assistant',
        'content': 'Requested Android command: $requestedCommand',
      });
      yield* _runLocalCommand(requestedCommand);
      _toolMessages.add(<String, String>{
        'role': 'user',
        'content': 'Android tool result:\n${_lastCommandOutput ?? ''}',
      });
    }
  }

  String _modelPrompt(String originalPrompt) {
    if (_lastCommandOutput == null) return originalPrompt;
    return 'The Android command has already been executed. Do not request it '
        'again and do not include private command tags.\n\n'
        'Original request:\n$originalPrompt\n\n'
        'Android tool result:\n$_lastCommandOutput\n\n'
        'Give the final user-facing answer now.';
  }

  String _toolResultText() {
    final output = _lastCommandOutput?.trim();
    if (output == null || output.isEmpty) return '';
    return 'Android command result:\n$output';
  }

  Stream<AgentStreamUpdate> _runLocalCommand(String command) async* {
    final eventId = 'android-command-${DateTime.now().microsecondsSinceEpoch}';
    _lastCommandOutput = null;
    _lastCommand = command;
    yield AgentEventUpdate(
      AgentEvent(
        id: eventId,
        kind: AgentEventKind.command,
        title: 'Running on Android',
        detail: command,
      ),
    );
    try {
      final result = await _runtimeBridge.runCommand(command);
      _lastCommandOutput = result.output.trim().isEmpty
          ? 'Exit code ${result.exitCode}'
          : result.output.trim();
      yield AgentEventUpdate(
        AgentEvent(
          id: eventId,
          kind: AgentEventKind.command,
          title: result.exitCode == 0
              ? 'Android command completed'
              : 'Android command failed',
          detail: result.output.trim().isEmpty
              ? 'Exit code ${result.exitCode}'
              : result.output.trim(),
          status: result.exitCode == 0
              ? AgentEventStatus.completed
              : AgentEventStatus.failed,
        ),
      );
    } on Object catch (error) {
      yield AgentEventUpdate(
        AgentEvent(
          id: eventId,
          kind: AgentEventKind.error,
          title: 'Android runtime error',
          detail: error.toString(),
          status: AgentEventStatus.failed,
        ),
      );
    }
  }

  String? _extractLocalCommand(String prompt) {
    final match = RegExp(
      r'\[\s*(?:run|command)\s*:\s*([^\]]+)\]',
      caseSensitive: false,
    ).firstMatch(prompt);
    return match?.group(1)?.trim();
  }

  String? _extractModelCommand(String text) {
    final match = RegExp(
      r'<android-command>\s*([a-z]+(?:[ ][A-Za-z0-9_./-]+)*)\s*</android-command>',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  String _withoutModelCommand(String text) {
    return text
        .replaceAll(
          RegExp(
            r'<android-command>\s*[a-z]+(?:[ ][A-Za-z0-9_./-]+)*\s*</android-command>',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async {
    try {
      final models = await _modelGateway.listModels(
        provider.copyWith(protocol: ProviderProtocol.openAICompatible),
      );
      if (models.isNotEmpty) return models;
    } on Object {
      // The on-device runtime can still operate with its configured model.
    }
    return <ModelInfo>[
      ModelInfo(
        id: provider.model,
        displayName: provider.model,
        isFree: true,
        supportsTools: true,
      ),
    ];
  }

  @override
  Future<void> testConnection(ProviderConfig provider) async {
    final info = await _runtimeBridge.getInfo();
    if (info == null) {
      throw const AgentGatewayException(
        'Android runtime bridge is unavailable on this platform.',
      );
    }
    await _modelGateway.testConnection(
      provider.copyWith(protocol: ProviderProtocol.openAICompatible),
    );
  }

  @override
  Future<void> respondToApproval({
    required ProviderConfig provider,
    required ApprovalRequest request,
    required bool approve,
    required bool allowForSession,
  }) async {}

  @override
  Future<void> interrupt({
    required AgentSession session,
    required ProviderConfig provider,
  }) async {
    _cancelled = true;
  }

  @override
  Future<void> dispose() async {
    await _modelGateway.dispose();
    await _fallbackGateway.dispose();
  }
}
