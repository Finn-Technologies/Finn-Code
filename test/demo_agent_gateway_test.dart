import 'package:finn_code/data/services/demo_agent_gateway.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo gateway streams agent activity and text', () async {
    final now = DateTime(2026, 9, 23);
    final session = AgentSession(
      id: 'session',
      title: 'Test',
      preview: '',
      providerId: 'finn-demo',
      model: 'finn-demo-v1',
      createdAt: now,
      updatedAt: now,
    );
    final provider = ProviderConfig.presets.first;
    final updates = await DemoAgentGateway()
        .streamReply(
          session: session,
          prompt: 'Test a free model on Android',
          provider: provider,
        )
        .toList();

    expect(updates.whereType<AgentEventUpdate>(), isNotEmpty);
    expect(updates.whereType<AgentReasoningDelta>(), isNotEmpty);
    expect(
      updates.whereType<AgentTextDelta>().map((item) => item.delta).join(),
      contains('Finn Demo'),
    );
    expect(updates.whereType<AgentTurnComplete>(), isNotEmpty);
  });
}
