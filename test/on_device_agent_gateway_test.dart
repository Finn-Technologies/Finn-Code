import 'package:finn_code/data/services/android_runtime_bridge.dart';
import 'package:finn_code/data/services/on_device_agent_gateway.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/model_info.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:finn_code/domain/services/agent_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRuntimeBridge extends AndroidRuntimeBridge {
  final List<String> commands = <String>[];

  @override
  Future<AndroidRuntimeInfo?> getInfo() async => const AndroidRuntimeInfo(
    runtimeId: 'android-test',
    platform: 'Android test',
    workspaceName: 'Test workspace',
    workspacePath: '/data/user/0/test/workspace',
    storageBytes: 0,
  );

  @override
  Future<AndroidCommandResult> runCommand(String command) async {
    commands.add(command);
    return const AndroidCommandResult(
      exitCode: 0,
      output: '/data/user/0/test/workspace',
    );
  }
}

class _FakeModelGateway implements AgentGateway {
  _FakeModelGateway({this.responses = const <String>[]});

  final List<String> responses;
  final List<String> prompts = <String>[];
  int _run = 0;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) {
    prompts.add(prompt);
    final response = responses.isEmpty
        ? (_run++ == 0
              ? '<android-command>pwd</android-command>'
              : 'ANDROID_MODEL_TOOL_OK')
        : responses[_run++ % responses.length];
    return Stream<AgentStreamUpdate>.fromIterable(<AgentStreamUpdate>[
      AgentTextDelta(response),
      const AgentTurnComplete(inputTokens: 10, outputTokens: 5),
    ]);
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async =>
      const <ModelInfo>[];

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

void main() {
  test(
    'keeps Android command markup private and follows the tool result',
    () async {
      final runtime = _FakeRuntimeBridge();
      final model = _FakeModelGateway();
      final gateway = OnDeviceAgentGateway(
        runtimeBridge: runtime,
        modelGateway: model,
      );
      final now = DateTime(2026, 9, 24);
      final session = AgentSession(
        id: 'session',
        title: 'Test',
        preview: '',
        providerId: 'android-on-device',
        model: 'space-bunny-free',
        createdAt: now,
        updatedAt: now,
      );

      final updates = await gateway
          .streamReply(
            session: session,
            prompt: 'Inspect the Android workspace.',
            provider: ProviderConfig.presets.firstWhere(
              (provider) => provider.id == 'android-on-device',
            ),
          )
          .toList();

      expect(runtime.commands, <String>['pwd']);
      expect(model.prompts, hasLength(2));
      expect(model.prompts.last, contains('Inspect the Android workspace.'));
      expect(model.prompts.last, contains('Android tool result:'));
      final text = updates
          .whereType<AgentTextDelta>()
          .map((item) => item.delta)
          .join();
      expect(text, 'ANDROID_MODEL_TOOL_OK');
      expect(text, isNot(contains('<android-command>')));
      expect(
        updates.whereType<AgentEventUpdate>().map((event) => event.event.title),
        contains('Android command completed'),
      );
      await gateway.dispose();
    },
  );

  test(
    'surfaces the native result when a provider repeats only its private tag',
    () async {
      final runtime = _FakeRuntimeBridge();
      final model = _FakeModelGateway(
        responses: <String>[
          '<android-command>pwd</android-command>',
          '<android-command>pwd</android-command>',
        ],
      );
      final gateway = OnDeviceAgentGateway(
        runtimeBridge: runtime,
        modelGateway: model,
      );
      final now = DateTime(2026, 9, 24);
      final session = AgentSession(
        id: 'session',
        title: 'Test',
        preview: '',
        providerId: 'android-on-device',
        model: 'space-bunny-free',
        createdAt: now,
        updatedAt: now,
      );

      final updates = await gateway
          .streamReply(
            session: session,
            prompt: 'Inspect the Android workspace.',
            provider: ProviderConfig.presets.firstWhere(
              (provider) => provider.id == 'android-on-device',
            ),
          )
          .toList();
      final text = updates
          .whereType<AgentTextDelta>()
          .map((update) => update.delta)
          .join();

      expect(runtime.commands, <String>['pwd']);
      expect(text, contains('Android command result:'));
      expect(text, contains('/data/user/0/test/workspace'));
      expect(text, isNot(contains('<android-command>')));
      await gateway.dispose();
    },
  );
}
