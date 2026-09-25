enum ProviderProtocol {
  demo,
  onDevice,
  openAICompatible,
  anthropic,
  gemini,
  codex,
}

extension ProviderProtocolX on ProviderProtocol {
  String get label => switch (this) {
    ProviderProtocol.demo => 'Demo runtime',
    ProviderProtocol.onDevice => 'Android on-device harness',
    ProviderProtocol.openAICompatible => 'OpenAI compatible',
    ProviderProtocol.anthropic => 'Anthropic Messages',
    ProviderProtocol.gemini => 'Google Gemini',
    ProviderProtocol.codex => 'Codex app-server',
  };

  String get shortLabel => switch (this) {
    ProviderProtocol.demo => 'Demo',
    ProviderProtocol.onDevice => 'Android',
    ProviderProtocol.openAICompatible => 'OpenAI API',
    ProviderProtocol.anthropic => 'Anthropic',
    ProviderProtocol.gemini => 'Gemini',
    ProviderProtocol.codex => 'Codex',
  };
}

class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
    this.description = '',
    this.isFreeTier = false,
    this.allowsAnonymousAccess = false,
    this.isBuiltIn = false,
    this.isLocal = false,
  });

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final String baseUrl;
  final String model;
  final String apiKey;
  final String description;
  final bool isFreeTier;
  final bool allowsAnonymousAccess;
  final bool isBuiltIn;
  final bool isLocal;

  bool get requiresApiKey => switch (protocol) {
    ProviderProtocol.demo ||
    ProviderProtocol.onDevice ||
    ProviderProtocol.codex => false,
    ProviderProtocol.openAICompatible ||
    ProviderProtocol.gemini => !isLocal && !allowsAnonymousAccess,
    ProviderProtocol.anthropic => true,
  };

  bool get supportsAgentTools =>
      protocol == ProviderProtocol.onDevice ||
      protocol == ProviderProtocol.codex;

  ProviderConfig copyWith({
    String? id,
    String? name,
    ProviderProtocol? protocol,
    String? baseUrl,
    String? model,
    String? apiKey,
    String? description,
    bool? isFreeTier,
    bool? allowsAnonymousAccess,
    bool? isBuiltIn,
    bool? isLocal,
  }) {
    return ProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      description: description ?? this.description,
      isFreeTier: isFreeTier ?? this.isFreeTier,
      allowsAnonymousAccess:
          allowsAnonymousAccess ?? this.allowsAnonymousAccess,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  Map<String, Object?> toPersistedMap() => <String, Object?>{
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'baseUrl': baseUrl,
    'model': model,
    'description': description,
    'isFreeTier': isFreeTier,
    'allowsAnonymousAccess': allowsAnonymousAccess,
    'isBuiltIn': isBuiltIn,
    'isLocal': isLocal,
  };

  factory ProviderConfig.fromPersistedMap(Map<String, Object?> map) {
    final protocolName = map['protocol'] as String?;
    return ProviderConfig(
      id: map['id'] as String,
      name: map['name'] as String,
      protocol: ProviderProtocol.values.firstWhere(
        (value) => value.name == protocolName,
        orElse: () => ProviderProtocol.openAICompatible,
      ),
      baseUrl: map['baseUrl'] as String? ?? '',
      model: map['model'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isFreeTier: map['isFreeTier'] as bool? ?? false,
      allowsAnonymousAccess: map['allowsAnonymousAccess'] as bool? ?? false,
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
      isLocal: map['isLocal'] as bool? ?? false,
    );
  }

  static const List<ProviderConfig> presets = <ProviderConfig>[
    ProviderConfig(
      id: 'finn-demo',
      name: 'Finn Demo Agent',
      protocol: ProviderProtocol.demo,
      baseUrl: '',
      model: 'finn-demo-v1',
      description: 'Offline product tour with realistic agent activity.',
      isFreeTier: true,
      isBuiltIn: true,
      isLocal: true,
    ),
    ProviderConfig(
      id: 'android-on-device',
      name: 'Android On-Device Harness',
      protocol: ProviderProtocol.onDevice,
      baseUrl: 'https://opencode.ai/zen/v1',
      model: 'space-bunny-free',
      description:
          'Android-owned workspace and tool runtime with Space Bunny as the model transport.',
      isFreeTier: true,
      allowsAnonymousAccess: true,
      isBuiltIn: true,
      isLocal: true,
    ),
    ProviderConfig(
      id: 'space-bunny-free',
      name: 'Space Bunny Free',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'https://opencode.ai/zen/v1',
      model: 'space-bunny-free',
      description: 'Free OpenCode Zen model. No API key required.',
      isFreeTier: true,
      allowsAnonymousAccess: true,
      isBuiltIn: true,
    ),
    ProviderConfig(
      id: 'llama-cpp-local',
      name: 'Local llama.cpp',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'http://10.0.2.2:11434/v1',
      model: 'FinnAI-Foundation',
      description: 'Free local model through the llama.cpp server.',
      isFreeTier: true,
      isBuiltIn: true,
      isLocal: true,
    ),
    ProviderConfig(
      id: 'ollama',
      name: 'Ollama',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'http://10.0.2.2:11434/v1',
      model: 'qwen2.5-coder:7b',
      description: 'Any Ollama model on this development machine.',
      isFreeTier: true,
      isBuiltIn: true,
      isLocal: true,
    ),
    ProviderConfig(
      id: 'openrouter-free',
      name: 'OpenRouter Free',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'https://openrouter.ai/api/v1',
      model: 'openrouter/free',
      description: 'Zero-cost model router; availability varies by region.',
      isFreeTier: true,
      isBuiltIn: true,
    ),
    ProviderConfig(
      id: 'groq-free',
      name: 'Groq Free Tier',
      protocol: ProviderProtocol.openAICompatible,
      baseUrl: 'https://api.groq.com/openai/v1',
      model: 'openai/gpt-oss-20b',
      description: 'Fast free-tier access to GPT-OSS and Qwen models.',
      isFreeTier: true,
      isBuiltIn: true,
    ),
    ProviderConfig(
      id: 'google-ai-studio',
      name: 'Google AI Studio',
      protocol: ProviderProtocol.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      model: 'gemini-2.5-flash',
      description: 'Gemini free tier through the native generateContent API.',
      isFreeTier: true,
      isBuiltIn: true,
    ),
    ProviderConfig(
      id: 'anthropic',
      name: 'Anthropic',
      protocol: ProviderProtocol.anthropic,
      baseUrl: 'https://api.anthropic.com/v1',
      model: 'claude-sonnet-4-5',
      description: 'Native Anthropic Messages API adapter.',
      isBuiltIn: true,
    ),
    ProviderConfig(
      id: 'codex-gateway',
      name: 'Codex Gateway',
      protocol: ProviderProtocol.codex,
      baseUrl: 'ws://10.0.2.2:4500',
      model: '',
      description:
          'Connect to codex app-server for tools, approvals, and files.',
      isBuiltIn: true,
      isLocal: true,
    ),
  ];
}
