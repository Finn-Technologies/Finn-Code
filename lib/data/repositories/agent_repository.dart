import '../../domain/models/provider_config.dart';
import '../../domain/services/agent_gateway.dart';
import '../services/anthropic_gateway.dart';
import '../services/codex_app_server_gateway.dart';
import '../services/demo_agent_gateway.dart';
import '../services/gemini_gateway.dart';
import '../services/on_device_agent_gateway.dart';
import '../services/openai_compatible_gateway.dart';

typedef AgentGatewayFactory = AgentGateway Function();

class AgentRepository {
  AgentRepository({
    Map<ProviderProtocol, AgentGateway>? gateways,
    Map<ProviderProtocol, AgentGatewayFactory>? gatewayFactories,
  }) {
    _gateways = <ProviderProtocol, AgentGateway>{
      ProviderProtocol.demo: DemoAgentGateway(),
      ProviderProtocol.onDevice: OnDeviceAgentGateway(),
      ProviderProtocol.openAICompatible: OpenAiCompatibleGateway(),
      ProviderProtocol.anthropic: AnthropicGateway(),
      ProviderProtocol.gemini: GeminiGateway(),
      ProviderProtocol.codex: CodexAppServerGateway(),
      ...?gateways,
    };
    _gatewayFactories = <ProviderProtocol, AgentGatewayFactory>{
      ProviderProtocol.demo: () => DemoAgentGateway(),
      ProviderProtocol.onDevice: () => OnDeviceAgentGateway(),
      ProviderProtocol.openAICompatible: () => OpenAiCompatibleGateway(),
      ProviderProtocol.anthropic: () => AnthropicGateway(),
      ProviderProtocol.gemini: () => GeminiGateway(),
      ProviderProtocol.codex: () => CodexAppServerGateway(),
      ...?gatewayFactories,
    };
  }

  late final Map<ProviderProtocol, AgentGateway> _gateways;
  late final Map<ProviderProtocol, AgentGatewayFactory> _gatewayFactories;
  final Map<AgentGateway, int> _runGatewayRefCounts = <AgentGateway, int>{};

  AgentGateway gatewayFor(ProviderConfig provider) {
    final gateway = _gateways[provider.protocol];
    if (gateway == null) {
      throw StateError('Unsupported provider protocol: ${provider.protocol}');
    }
    return gateway;
  }

  AgentGateway createGatewayFor(ProviderConfig provider) {
    final factory = _gatewayFactories[provider.protocol];
    if (factory == null) {
      throw StateError('Unsupported provider protocol: ${provider.protocol}');
    }
    final gateway = factory();
    _runGatewayRefCounts.update(
      gateway,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return gateway;
  }

  Future<void> releaseGateway(AgentGateway gateway) async {
    final count = _runGatewayRefCounts[gateway];
    if (count == null || count <= 0) return;
    if (count > 1) {
      _runGatewayRefCounts[gateway] = count - 1;
      return;
    }
    _runGatewayRefCounts.remove(gateway);
    if (!_gateways.values.any((shared) => identical(shared, gateway))) {
      await gateway.dispose();
    }
  }

  Future<void> dispose() async {
    final gateways = <AgentGateway>{
      ..._gateways.values,
      ..._runGatewayRefCounts.keys,
    };
    _runGatewayRefCounts.clear();
    for (final gateway in gateways) {
      await gateway.dispose();
    }
  }
}
