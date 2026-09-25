enum AgentEventKind {
  status,
  reasoning,
  tool,
  fileChange,
  command,
  diff,
  error,
}

enum AgentEventStatus { queued, running, completed, failed, declined }

class AgentEvent {
  const AgentEvent({
    required this.id,
    required this.kind,
    required this.title,
    this.detail = '',
    this.status = AgentEventStatus.running,
    this.additions,
    this.deletions,
  });

  final String id;
  final AgentEventKind kind;
  final String title;
  final String detail;
  final AgentEventStatus status;
  final int? additions;
  final int? deletions;

  AgentEvent copyWith({
    String? title,
    String? detail,
    AgentEventStatus? status,
    int? additions,
    int? deletions,
  }) {
    return AgentEvent(
      id: id,
      kind: kind,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
    );
  }
}
