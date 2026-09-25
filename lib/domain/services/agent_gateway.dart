import '../models/agent_session.dart';
import '../models/agent_stream_update.dart';
import '../models/model_info.dart';
import '../models/provider_config.dart';

abstract interface class AgentGateway {
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  });

  Future<List<ModelInfo>> listModels(ProviderConfig provider);

  Future<void> testConnection(ProviderConfig provider);

  Future<void> respondToApproval({
    required ProviderConfig provider,
    required ApprovalRequest request,
    required bool approve,
    required bool allowForSession,
  });

  Future<void> interrupt({
    required AgentSession session,
    required ProviderConfig provider,
  });

  Future<void> dispose();
}
