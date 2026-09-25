import 'package:finn_code/data/services/android_runtime_bridge.dart';
import 'package:finn_code/data/services/on_device_agent_gateway.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/model_info.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:finn_code/domain/services/agent_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _CommandModelGateway implements AgentGateway {
  int _run = 0;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) {
    final response = _run++ == 0
        ? '<android-command>pwd</android-command>'
        : 'ANDROID_MODEL_TOOL_OK';
    return Stream<AgentStreamUpdate>.fromIterable(<AgentStreamUpdate>[
      AgentTextDelta(response),
      const AgentTurnComplete(inputTokens: 12, outputTokens: 6),
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owns a workspace and runs a constrained command on Android', (
    tester,
  ) async {
    final bridge = AndroidRuntimeBridge();
    final info = await bridge.getInfo();

    expect(info, isNotNull);
    expect(info!.runtimeId, startsWith('android-'));
    expect(info.platform, startsWith('Android'));
    expect(info.workspaceName, isNotEmpty);
    expect(info.workspacePath, isNotEmpty);

    const path = 'android_runtime_probe.txt';
    const content = 'ANDROID_RUNTIME_FILE_OK';
    await bridge.writeFile(path, content);
    expect(await bridge.readFile(path), content);

    final result = await bridge.runCommand('cat android_runtime_probe.txt');
    expect(result.exitCode, 0);
    expect(result.output, contains(content));

    await bridge.deleteFile(path);
  });

  testWidgets(
    'runs a model-requested command through the native Android runtime',
    (tester) async {
      final gateway = OnDeviceAgentGateway(
        modelGateway: _CommandModelGateway(),
      );
      final now = DateTime.now();
      final session = AgentSession(
        id: 'android-model-tool-session',
        title: 'Android model tool session',
        preview: '',
        providerId: 'android-on-device',
        model: 'space-bunny-free',
        createdAt: now,
        updatedAt: now,
      );

      final updates = await gateway
          .streamReply(
            session: session,
            prompt: 'Inspect the current Android workspace.',
            provider: ProviderConfig.presets.firstWhere(
              (provider) => provider.id == 'android-on-device',
            ),
          )
          .toList();
      final text = updates
          .whereType<AgentTextDelta>()
          .map((update) => update.delta)
          .join();

      expect(text, 'ANDROID_MODEL_TOOL_OK');
      expect(text, isNot(contains('<android-command>')));
      expect(
        updates.whereType<AgentEventUpdate>().map(
          (update) => update.event.title,
        ),
        contains('Android command completed'),
      );
      await gateway.dispose();
    },
  );
}
