import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_session.dart';
import '../../domain/models/agent_stream_update.dart';
import '../../domain/models/model_info.dart';
import '../../domain/models/provider_config.dart';
import '../../domain/services/agent_gateway.dart';

class DemoAgentGateway implements AgentGateway {
  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) async* {
    yield const AgentEventUpdate(
      AgentEvent(
        id: 'demo-plan',
        kind: AgentEventKind.status,
        title: 'Reading the request',
        detail: 'Mapping the task into a safe mobile workflow.',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    yield const AgentEventUpdate(
      AgentEvent(
        id: 'demo-plan',
        kind: AgentEventKind.status,
        title: 'Plan ready',
        detail: 'Inspect → implement → verify',
        status: AgentEventStatus.completed,
      ),
    );
    yield const AgentReasoningDelta(
      'I will make the first response feel like a real agent without pretending to execute unsafe tools. ',
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    yield const AgentEventUpdate(
      AgentEvent(
        id: 'demo-tool',
        kind: AgentEventKind.tool,
        title: 'Preparing workspace context',
        detail: 'Read project instructions and recent changes',
        status: AgentEventStatus.running,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield const AgentEventUpdate(
      AgentEvent(
        id: 'demo-tool',
        kind: AgentEventKind.tool,
        title: 'Workspace inspected',
        detail: 'No destructive commands requested',
        status: AgentEventStatus.completed,
      ),
    );
    yield const AgentReasoningDelta(
      'The task is clear, so I will summarize the next concrete action. ',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    yield const AgentEventUpdate(
      AgentEvent(
        id: 'demo-diff',
        kind: AgentEventKind.diff,
        title: 'Suggested change set',
        detail: 'lib/app.dart · lib/ui/app_shell.dart',
        status: AgentEventStatus.completed,
        additions: 18,
        deletions: 3,
      ),
    );

    final response = _responseFor(prompt);
    for (final chunk in response.split(RegExp(r'(?<=\s)'))) {
      if (chunk.isEmpty) continue;
      yield AgentTextDelta(chunk);
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
    yield const AgentTurnComplete(inputTokens: 248, outputTokens: 96);
  }

  String _responseFor(String prompt) {
    final normalized = prompt.toLowerCase();
    if (normalized.contains('free') || normalized.contains('model')) {
      return 'I would start with Finn Demo for UI work, local llama.cpp for a keyless end-to-end smoke test, and OpenRouter Free or Groq when you want a hosted model. The provider boundary is the same for all of them.';
    }
    if (normalized.contains('android') || normalized.contains('flutter')) {
      return 'The Android path is ready: this response is streamed from the demo gateway, rendered as a native Flutter message, and persisted in the same session model used by real providers. Switch to Local llama.cpp to test a genuinely free model on the next run.';
    }
    return 'I would handle this in three passes: confirm the Android target and project path, make the smallest provider-agnostic change, then run tests and inspect the app on the emulator. Connect the Codex Gateway when the task needs real file edits, commands, or approval-gated tools.';
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async =>
      const <ModelInfo>[
        ModelInfo(
          id: 'finn-demo-v1',
          displayName: 'Finn Demo v1',
          isFree: true,
          supportsTools: true,
        ),
        ModelInfo(
          id: 'finn-demo-coder',
          displayName: 'Finn Demo Coder',
          isFree: true,
          supportsTools: true,
        ),
      ];

  @override
  Future<void> testConnection(ProviderConfig provider) async {}

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
  }) async {}

  @override
  Future<void> dispose() async {}
}
