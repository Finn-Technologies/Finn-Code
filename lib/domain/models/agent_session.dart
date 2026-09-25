import 'agent_message.dart';

enum SessionStatus { idle, running, waitingApproval, failed }

class AgentSession {
  const AgentSession({
    required this.id,
    required this.title,
    required this.preview,
    required this.providerId,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.projectPath = '',
    this.status = SessionStatus.idle,
    this.messages = const <AgentMessage>[],
    this.remoteThreadId,
    this.isPinned = false,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String preview;
  final String providerId;
  final String model;
  final String projectPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SessionStatus status;
  final List<AgentMessage> messages;
  final String? remoteThreadId;
  final bool isPinned;
  final bool isArchived;

  AgentSession copyWith({
    String? title,
    String? preview,
    String? providerId,
    String? model,
    String? projectPath,
    DateTime? updatedAt,
    SessionStatus? status,
    List<AgentMessage>? messages,
    String? remoteThreadId,
    bool? isPinned,
    bool? isArchived,
  }) {
    return AgentSession(
      id: id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      projectPath: projectPath ?? this.projectPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      remoteThreadId: remoteThreadId ?? this.remoteThreadId,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
