import 'agent_event.dart';

sealed class AgentStreamUpdate {
  const AgentStreamUpdate();
}

class AgentTextDelta extends AgentStreamUpdate {
  const AgentTextDelta(this.delta, {this.isFinalAnswer = true});

  final String delta;
  final bool isFinalAnswer;
}

class AgentReasoningDelta extends AgentStreamUpdate {
  const AgentReasoningDelta(this.delta);

  final String delta;
}

class AgentEventUpdate extends AgentStreamUpdate {
  const AgentEventUpdate(this.event);

  final AgentEvent event;
}

class AgentRemoteThread extends AgentStreamUpdate {
  const AgentRemoteThread(this.threadId);

  final String threadId;
}

class AgentTurnComplete extends AgentStreamUpdate {
  const AgentTurnComplete({this.inputTokens, this.outputTokens});

  final int? inputTokens;
  final int? outputTokens;
}

class AgentFailure extends AgentStreamUpdate {
  const AgentFailure(this.message, {this.code});

  final String message;
  final int? code;
}

enum ApprovalKind { command, fileChange, permission }

class ApprovalRequest {
  const ApprovalRequest({
    required this.requestId,
    required this.kind,
    required this.title,
    this.detail = '',
    this.command,
    this.cwd,
    this.rawParams = const <String, dynamic>{},
  });

  final Object requestId;
  final ApprovalKind kind;
  final String title;
  final String detail;
  final String? command;
  final String? cwd;
  final Map<String, dynamic> rawParams;
}

class AgentApprovalRequired extends AgentStreamUpdate {
  const AgentApprovalRequired(this.request);

  final ApprovalRequest request;
}
