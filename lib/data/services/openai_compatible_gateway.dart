import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/agent_message.dart';
import '../../domain/models/agent_session.dart';
import '../../domain/models/agent_stream_update.dart';
import '../../domain/models/model_info.dart';
import '../../domain/models/provider_config.dart';
import '../../domain/services/agent_gateway.dart';
import 'sse.dart';

class OpenAiCompatibleGateway implements AgentGateway {
  OpenAiCompatibleGateway({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) async* {
    final request = http.Request(
      'POST',
      apiUri(provider.baseUrl, 'chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      if (provider.apiKey.isNotEmpty)
        'Authorization': 'Bearer ${provider.apiKey}',
      if (provider.id == 'openrouter-free') ...<String, String>{
        'HTTP-Referer': 'https://github.com/Finn-Technologies/Finn-Code',
        'X-Title': 'Finn Code',
      },
    });
    request.body = jsonEncode(<String, Object?>{
      'model': provider.model,
      'stream': true,
      'max_tokens': 1600,
      'messages': _messagesFor(session, prompt, provider),
    });

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwHttpError(
        provider.name,
        response.statusCode,
        await response.stream.bytesToString(),
      );
    }

    await for (final event in decodeSseData(response.stream)) {
      final choices = event['choices'];
      if (choices is List && choices.isNotEmpty) {
        final choice = choices.first;
        if (choice is Map<String, dynamic>) {
          final delta = choice['delta'];
          if (delta is Map<String, dynamic>) {
            final reasoning = (delta['reasoning_content'] ?? delta['reasoning'])
                ?.toString();
            if (reasoning != null && reasoning.isNotEmpty) {
              yield AgentReasoningDelta(reasoning);
            }
            final content = delta['content']?.toString();
            if (content != null && content.isNotEmpty) {
              yield AgentTextDelta(content);
            }
          }
        }
      }
      final usage = event['usage'];
      if (usage is Map<String, dynamic>) {
        yield AgentTurnComplete(
          inputTokens: (usage['prompt_tokens'] as num?)?.toInt(),
          outputTokens: (usage['completion_tokens'] as num?)?.toInt(),
        );
      }
    }
  }

  List<Map<String, String>> _messagesFor(
    AgentSession session,
    String prompt,
    ProviderConfig provider,
  ) {
    final systemPrompt = provider.id == 'android-on-device-transport'
        ? 'You are Finn Code running as an Android on-device coding harness. '
              'You can inspect the app-private workspace with read-only commands. '
              'When a command is needed, respond with exactly '
              '<android-command>command</android-command> and no other final text. '
              'Allowed commands: pwd, ls, find, grep, cat, wc, du, df, date, '
              'whoami, echo. Arguments may contain only letters, numbers, spaces, '
              'underscore, dot, slash, and hyphen. After a tool result, explain '
              'the outcome briefly. Never claim commands ran unless a tool result '
              'is present.'
        : 'You are Finn Code, a concise mobile AI coding assistant. Explain '
              'actions clearly and never claim to have changed files unless a '
              'connected Codex runtime confirms it.';
    final messages = <Map<String, String>>[
      <String, String>{'role': 'system', 'content': systemPrompt},
    ];
    for (final message in session.messages) {
      if (message.role == MessageRole.system ||
          message.content.trim().isEmpty) {
        continue;
      }
      messages.add(<String, String>{
        'role': message.role == MessageRole.user ? 'user' : 'assistant',
        'content': message.content,
      });
    }
    messages.add(<String, String>{'role': 'user', 'content': prompt});
    return messages;
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async {
    final response = await _client.get(
      apiUri(provider.baseUrl, 'models'),
      headers: <String, String>{
        if (provider.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${provider.apiKey}',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwHttpError(provider.name, response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const <ModelInfo>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ModelInfo.fromOpenAiJson)
        .toList(growable: false);
  }

  @override
  Future<void> testConnection(ProviderConfig provider) async {
    final models = await listModels(provider);
    if (models.isEmpty && provider.model.trim().isEmpty) {
      throw const AgentGatewayException(
        'Connected, but the provider returned no models. Set a model manually.',
      );
    }
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
  }) async {}

  @override
  Future<void> dispose() async => _client.close();
}
