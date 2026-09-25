import 'package:finn_code/domain/models/provider_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in presets include demo, local, hosted, and Codex runtimes', () {
    final protocols = ProviderConfig.presets
        .map((provider) => provider.protocol)
        .toSet();

    expect(protocols, contains(ProviderProtocol.demo));
    expect(protocols, contains(ProviderProtocol.openAICompatible));
    expect(protocols, contains(ProviderProtocol.anthropic));
    expect(protocols, contains(ProviderProtocol.gemini));
    expect(protocols, contains(ProviderProtocol.codex));
  });

  test('persisted provider maps never include API keys', () {
    const provider = ProviderConfig(
      id: 'custom',
      name: 'Custom',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'https://example.com/v1',
      model: 'model',
      apiKey: 'secret',
    );

    expect(provider.toPersistedMap(), isNot(contains('apiKey')));
    final restored = ProviderConfig.fromPersistedMap(provider.toPersistedMap());
    expect(restored.apiKey, isEmpty);
    expect(restored.model, 'model');
  });

  test('Space Bunny Free is an anonymous built-in provider', () {
    final bunny = ProviderConfig.presets.firstWhere(
      (provider) => provider.id == 'space-bunny-free',
    );

    expect(bunny.name, 'Space Bunny Free');
    expect(bunny.baseUrl, 'https://opencode.ai/zen/v1');
    expect(bunny.model, 'space-bunny-free');
    expect(bunny.isFreeTier, isTrue);
    expect(bunny.allowsAnonymousAccess, isTrue);
    expect(bunny.requiresApiKey, isFalse);
  });
}
