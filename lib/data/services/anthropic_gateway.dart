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

class AnthropicGateway implements AgentGateway {
  AnthropicGateway({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) async* {
    final messages = <Map<String, String>>[];
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

    final request = http.Request('POST', apiUri(provider.baseUrl, 'messages'));
    request.headers.addAll(<String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'anthropic-version': '2023-06-01',
      'x-api-key': provider.apiKey,
    });
    request.body = jsonEncode(<String, Object?>{
      'model': provider.model,
      'max_tokens': 1600,
      'stream': true,
      'system':
          'You are Finn Code, a concise mobile AI coding assistant. Never claim to have edited files in chat-only mode.',
      'messages': messages,
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
      final type = event['type'];
      if (type == 'content_block_delta') {
        final delta = event['delta'];
        if (delta is Map<String, dynamic>) {
          final text = delta['text']?.toString();
          if (text != null && text.isNotEmpty) yield AgentTextDelta(text);
          final thinking = delta['thinking']?.toString();
          if (thinking != null && thinking.isNotEmpty) {
            yield AgentReasoningDelta(thinking);
          }
        }
      } else if (type == 'message_delta') {
        final usage = event['usage'];
        if (usage is Map<String, dynamic>) {
          yield AgentTurnComplete(
            inputTokens: (usage['input_tokens'] as num?)?.toInt(),
            outputTokens: (usage['output_tokens'] as num?)?.toInt(),
          );
        }
      }
    }
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async {
    final response = await _client.get(
      apiUri(provider.baseUrl, 'models'),
      headers: <String, String>{
        'x-api-key': provider.apiKey,
        'anthropic-version': '2023-06-01',
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
        .map(
          (item) => ModelInfo(
            id: item['id'] as String,
            displayName:
                item['display_name'] as String? ?? item['id'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> testConnection(ProviderConfig provider) async {
    await listModels(provider);
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
