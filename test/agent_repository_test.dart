import 'package:finn_code/data/repositories/agent_repository.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/model_info.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:finn_code/domain/services/agent_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositoryTestGateway implements AgentGateway {
  int disposeCount = 0;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) => const Stream<AgentStreamUpdate>.empty();

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
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  test('uses an injected gateway for each run and releases it once', () async {
    final shared = _RepositoryTestGateway();
    final repository = AgentRepository(
      gatewayFactories: <ProviderProtocol, AgentGatewayFactory>{
        ProviderProtocol.demo: () => shared,
      },
    );
    const provider = ProviderConfig(
      id: 'demo',
      name: 'Demo',
      protocol: ProviderProtocol.demo,
      baseUrl: '',
      model: 'demo',
    );

    final first = repository.createGatewayFor(provider);
    final second = repository.createGatewayFor(provider);
    expect(first, same(shared));
    expect(second, same(shared));

    await repository.releaseGateway(first);
    expect(shared.disposeCount, 0);
    await repository.releaseGateway(second);
    expect(shared.disposeCount, 1);

    await repository.dispose();
    expect(shared.disposeCount, 1);
  });
}
