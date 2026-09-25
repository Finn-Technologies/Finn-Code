import 'dart:convert';

import 'package:finn_code/data/services/anthropic_gateway.dart';
import 'package:finn_code/data/services/gemini_gateway.dart';
import 'package:finn_code/data/services/openai_compatible_gateway.dart';
import 'package:finn_code/data/services/sse.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _TestHttpClient extends http.BaseClient {
  _TestHttpClient(this.handler);

  final Future<http.Response> Function(http.Request request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    final captured = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = body;
    final response = await handler(captured);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: response.request,
    );
  }
}

AgentSession _session() {
  final now = DateTime(2026, 9, 23);
  return AgentSession(
    id: 'session',
    title: 'Test',
    preview: '',
    providerId: 'test',
    model: 'model',
    createdAt: now,
    updatedAt: now,
  );
}

ProviderConfig _provider({
  required ProviderProtocol protocol,
  required String baseUrl,
  String id = 'test',
  String model = 'model',
  String apiKey = 'secret',
}) {
  return ProviderConfig(
    id: id,
    name: 'Test provider',
    protocol: protocol,
    baseUrl: baseUrl,
    model: model,
    apiKey: apiKey,
  );
}

void main() {
  group('OpenAI-compatible gateway', () {
    test('streams text, reasoning, usage, and sends auth headers', () async {
      late http.Request request;
      final client = _TestHttpClient((incoming) async {
        request = incoming;
        return http.Response(
          'data: {"choices":[{"delta":{"reasoning_content":"think","content":"hello"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":" world"}}],"usage":{"prompt_tokens":7,"completion_tokens":3}}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        );
      });
      final gateway = OpenAiCompatibleGateway(client: client);
      final provider = _provider(
        protocol: ProviderProtocol.openAICompatible,
        baseUrl: 'https://example.com/v1/',
        id: 'openrouter-free',
      );

      final updates = await gateway
          .streamReply(session: _session(), prompt: 'Hi', provider: provider)
          .toList();

      expect(request.url.toString(), 'https://example.com/v1/chat/completions');
      expect(request.headers['Authorization'], 'Bearer secret');
      expect(request.headers['X-Title'], 'Finn Code');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['stream'], isTrue);
      expect((body['messages'] as List<dynamic>).last, <String, String>{
        'role': 'user',
        'content': 'Hi',
      });
      expect(
        updates.whereType<AgentTextDelta>().map((item) => item.delta).join(),
        'hello world',
      );
      expect(updates.whereType<AgentReasoningDelta>().single.delta, 'think');
      final usage = updates.whereType<AgentTurnComplete>().single;
      expect(usage.inputTokens, 7);
      expect(usage.outputTokens, 3);
    });

    test('parses model discovery and reports HTTP errors', () async {
      final client = _TestHttpClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response(
            '{"data":[{"id":"model-a","name":"Model A","context_length":4096}]}',
            200,
          );
        }
        return http.Response('bad request', 400);
      });
      final gateway = OpenAiCompatibleGateway(client: client);
      final provider = _provider(
        protocol: ProviderProtocol.openAICompatible,
        baseUrl: 'https://example.com/v1',
      );

      final models = await gateway.listModels(provider);
      expect(models.single.id, 'model-a');
      expect(models.single.contextWindow, 4096);

      await expectLater(
        gateway
            .streamReply(session: _session(), prompt: 'Hi', provider: provider)
            .toList(),
        throwsA(
          isA<AgentGatewayException>().having(
            (error) => error.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    });
  });

  group('Anthropic gateway', () {
    test('streams text and usage with the Anthropic API shape', () async {
      late http.Request request;
      final client = _TestHttpClient((incoming) async {
        request = incoming;
        return http.Response(
          'data: {"type":"content_block_delta","delta":{"text":"Hi"}}\n\n'
          'data: {"type":"content_block_delta","delta":{"thinking":"plan"}}\n\n'
          'data: {"type":"message_delta","usage":{"input_tokens":4,"output_tokens":2}}\n\n',
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        );
      });
      final gateway = AnthropicGateway(client: client);
      final provider = _provider(
        protocol: ProviderProtocol.anthropic,
        baseUrl: 'https://api.anthropic.com/v1',
      );

      final updates = await gateway
          .streamReply(session: _session(), prompt: 'Hi', provider: provider)
          .toList();

      expect(request.url.path, '/v1/messages');
      expect(request.headers['x-api-key'], 'secret');
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(updates.whereType<AgentTextDelta>().single.delta, 'Hi');
      expect(updates.whereType<AgentReasoningDelta>().single.delta, 'plan');
      expect(updates.whereType<AgentTurnComplete>().single.inputTokens, 4);
    });

    test('maps model discovery ids and display names', () async {
      final client = _TestHttpClient(
        (_) async => http.Response(
          '{"data":[{"id":"claude-a","display_name":"Claude A"}]}',
          200,
        ),
      );
      final gateway = AnthropicGateway(client: client);
      final models = await gateway.listModels(
        _provider(
          protocol: ProviderProtocol.anthropic,
          baseUrl: 'https://api.anthropic.com/v1',
        ),
      );
      expect(models.single.id, 'claude-a');
      expect(models.single.displayName, 'Claude A');
    });
  });

  group('Gemini gateway', () {
    test('streams candidate text and usage from the SSE API', () async {
      late http.Request request;
      final client = _TestHttpClient((incoming) async {
        request = incoming;
        return http.Response(
          'data: {"candidates":[{"content":{"parts":[{"text":"Hello"},{"text":" world"}]}}]}\n\n'
          'data: {"usageMetadata":{"promptTokenCount":5,"candidatesTokenCount":2}}\n\n',
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        );
      });
      final gateway = GeminiGateway(client: client);
      final provider = _provider(
        protocol: ProviderProtocol.gemini,
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        model: 'models/gemini-a',
      );

      final updates = await gateway
          .streamReply(session: _session(), prompt: 'Hi', provider: provider)
          .toList();

      expect(request.url.path, '/v1beta/models/gemini-a:streamGenerateContent');
      expect(request.url.queryParameters['alt'], 'sse');
      expect(request.headers['x-goog-api-key'], 'secret');
      expect(
        updates.whereType<AgentTextDelta>().map((item) => item.delta).join(),
        'Hello world',
      );
      expect(updates.whereType<AgentTurnComplete>().single.outputTokens, 2);
    });

    test('filters models without a supported generation method', () async {
      final client = _TestHttpClient(
        (_) async => http.Response(
          '{"models":[{"name":"models/gemini-a","displayName":"Gemini A","supportedGenerationMethods":["generateContent"]},{"name":"models/embed"}]}',
          200,
        ),
      );
      final gateway = GeminiGateway(client: client);
      final models = await gateway.listModels(
        _provider(
          protocol: ProviderProtocol.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        ),
      );
      expect(models, hasLength(1));
      expect(models.single.id, 'gemini-a');
    });
  });
}
