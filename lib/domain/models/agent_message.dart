import 'agent_event.dart';

enum MessageRole { user, assistant, system }

enum MessageStatus { complete, streaming, error }

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.complete,
    this.reasoning = '',
    this.events = const <AgentEvent>[],
    this.isFinalAnswer = true,
  });

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final MessageStatus status;
  final String reasoning;
  final List<AgentEvent> events;
  final bool isFinalAnswer;

  AgentMessage copyWith({
    String? content,
    MessageStatus? status,
    String? reasoning,
    List<AgentEvent>? events,
    bool? isFinalAnswer,
  }) {
    return AgentMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      status: status ?? this.status,
      reasoning: reasoning ?? this.reasoning,
      events: events ?? this.events,
      isFinalAnswer: isFinalAnswer ?? this.isFinalAnswer,
    );
  }
}
