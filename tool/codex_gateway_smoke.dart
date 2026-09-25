import 'dart:io';

import 'package:finn_code/data/services/codex_app_server_gateway.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/provider_config.dart';

Future<void> main() async {
  final url =
      Platform.environment['FINN_CODEX_APP_SERVER_URL'] ??
      'ws://127.0.0.1:4599';
  final provider = ProviderConfig(
    id: 'codex-smoke',
    name: 'Codex smoke',
    protocol: ProviderProtocol.codex,
    baseUrl: url,
    model: '',
  );
  final gateway = CodexAppServerGateway();

  try {
    await gateway.testConnection(provider);
    stdout.writeln('Codex gateway handshake passed: $url');
    try {
      final models = await gateway.listModels(provider);
      stdout.writeln('Codex model discovery passed: ${models.length} models');
    } on Object catch (error) {
      stdout.writeln('Codex model discovery unavailable: $error');
    }
    if (Platform.environment['FINN_CODEX_RUN_TURN'] == '1') {
      final now = DateTime.now();
      final session = AgentSession(
        id: 'codex-smoke-session',
        title: 'Codex smoke',
        preview: '',
        providerId: provider.id,
        model: '',
        createdAt: now,
        updatedAt: now,
      );
      final updates = await gateway
          .streamReply(
            session: session,
            prompt: 'Reply with a short status update. Do not use tools.',
            provider: provider,
          )
          .timeout(const Duration(seconds: 45))
          .toList();
      stdout.writeln('Codex read-only turn passed: ${updates.length} updates');
    }
  } finally {
    await gateway.dispose();
  }
}
