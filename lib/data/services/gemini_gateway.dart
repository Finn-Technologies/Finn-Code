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

class GeminiGateway implements AgentGateway {
  GeminiGateway({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) async* {
    final model = provider.model.startsWith('models/')
        ? provider.model.substring('models/'.length)
        : provider.model;
    final request = http.Request(
      'POST',
      apiUri(
        provider.baseUrl,
        'models/$model:streamGenerateContent',
        query: <String, String>{'alt': 'sse'},
      ),
    );
    request.headers.addAll(<String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'x-goog-api-key': provider.apiKey,
    });
    request.body = jsonEncode(<String, Object?>{
      'systemInstruction': <String, Object?>{
        'parts': <Map<String, String>>[
          <String, String>{
            'text':
                'You are Finn Code, a concise mobile AI coding assistant. Never claim to have edited files in chat-only mode.',
          },
        ],
      },
      'contents': _contentsFor(session, prompt),
      'generationConfig': <String, Object?>{
        'maxOutputTokens': 1600,
        'temperature': 0.4,
      },
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
      final candidates = event['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final candidate = candidates.first;
        if (candidate is Map<String, dynamic>) {
          final content = candidate['content'];
          if (content is Map<String, dynamic>) {
            final parts = content['parts'];
            if (parts is List) {
              for (final part in parts.whereType<Map<String, dynamic>>()) {
                final text = part['text']?.toString();
                if (text != null && text.isNotEmpty) yield AgentTextDelta(text);
              }
            }
          }
        }
      }
      final usage = event['usageMetadata'];
      if (usage is Map<String, dynamic>) {
        yield AgentTurnComplete(
          inputTokens: (usage['promptTokenCount'] as num?)?.toInt(),
          outputTokens: (usage['candidatesTokenCount'] as num?)?.toInt(),
        );
      }
    }
  }

  List<Map<String, Object?>> _contentsFor(AgentSession session, String prompt) {
    final contents = <Map<String, Object?>>[];
    for (final message in session.messages) {
      if (message.role == MessageRole.system ||
          message.content.trim().isEmpty) {
        continue;
      }
      contents.add(<String, Object?>{
        'role': message.role == MessageRole.user ? 'user' : 'model',
        'parts': <Map<String, String>>[
          <String, String>{'text': message.content},
        ],
      });
    }
    contents.add(<String, Object?>{
      'role': 'user',
      'parts': <Map<String, String>>[
        <String, String>{'text': prompt},
      ],
    });
    return contents;
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async {
    final response = await _client.get(
      apiUri(provider.baseUrl, 'models'),
      headers: <String, String>{'x-goog-api-key': provider.apiKey},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwHttpError(provider.name, response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final models = body['models'];
    if (models is! List) return const <ModelInfo>[];
    return models
        .whereType<Map<String, dynamic>>()
        .where((item) => item['supportedGenerationMethods'] is List)
        .map(
          (item) => ModelInfo(
            id: (item['name'] as String).replaceFirst('models/', ''),
            displayName:
                item['displayName'] as String? ??
                (item['name'] as String).replaceFirst('models/', ''),
            contextWindow: (item['inputTokenLimit'] as num?)?.toInt(),
            isFree: provider.isFreeTier,
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
