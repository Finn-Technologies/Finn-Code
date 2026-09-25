import 'dart:convert';

import '../../domain/models/agent_event.dart';
import '../../domain/models/agent_message.dart';
import '../../domain/models/agent_session.dart';

abstract final class SessionCodec {
  static const schemaVersion = 3;

  static String encode(List<AgentSession> sessions) {
    return jsonEncode(<String, Object?>{
      'version': schemaVersion,
      'sessions': sessions.map(_sessionToMap).toList(growable: false),
    });
  }

  static List<AgentSession> decode(String value) {
    try {
      final decoded = jsonDecode(value);
      final rawSessions = switch (decoded) {
        Map<String, dynamic> map
            when map['version'] == schemaVersion || map['version'] == 2 =>
          map['sessions'],
        List<dynamic> list => list,
        _ => null,
      };
      if (rawSessions is! List) return const <AgentSession>[];
      return rawSessions
          .whereType<Map<String, dynamic>>()
          .map(_sessionFromMap)
          .whereType<AgentSession>()
          .toList(growable: false);
    } on FormatException {
      return const <AgentSession>[];
    } on TypeError {
      return const <AgentSession>[];
    }
  }

  static Map<String, Object?> _sessionToMap(AgentSession session) {
    return <String, Object?>{
      'id': session.id,
      'title': session.title,
      'preview': session.preview,
      'providerId': session.providerId,
      'model': session.model,
      'projectPath': session.projectPath,
      'createdAt': session.createdAt.toIso8601String(),
      'updatedAt': session.updatedAt.toIso8601String(),
      'status': session.status.name,
      'remoteThreadId': session.remoteThreadId,
      'isPinned': session.isPinned,
      'isArchived': session.isArchived,
      'messages': session.messages.map(_messageToMap).toList(growable: false),
    };
  }

  static Map<String, Object?> _messageToMap(AgentMessage message) {
    return <String, Object?>{
      'id': message.id,
      'role': message.role.name,
      'content': message.content,
      'createdAt': message.createdAt.toIso8601String(),
      'status': message.status.name,
      'reasoning': message.reasoning,
      'events': message.events.map(_eventToMap).toList(growable: false),
      'isFinalAnswer': message.isFinalAnswer,
    };
  }

  static Map<String, Object?> _eventToMap(AgentEvent event) {
    return <String, Object?>{
      'id': event.id,
      'kind': event.kind.name,
      'title': event.title,
      'detail': event.detail,
      'status': event.status.name,
      'additions': event.additions,
      'deletions': event.deletions,
    };
  }

  static AgentSession? _sessionFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    final preview = map['preview'];
    final providerId = map['providerId'];
    final model = map['model'];
    final createdAt = _date(map['createdAt']);
    final updatedAt = _date(map['updatedAt']);
    if (id is! String ||
        title is! String ||
        preview is! String ||
        providerId is! String ||
        model is! String ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }
    return AgentSession(
      id: id,
      title: title,
      preview: preview,
      providerId: providerId,
      model: model,
      projectPath: map['projectPath'] is String
          ? map['projectPath'] as String
          : '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      status:
          _enumValue(SessionStatus.values, map['status'], SessionStatus.idle) ??
          SessionStatus.idle,
      messages: _messages(map['messages']),
      remoteThreadId: map['remoteThreadId'] is String
          ? map['remoteThreadId'] as String
          : null,
      isPinned: map['isPinned'] is bool ? map['isPinned'] as bool : false,
      isArchived: map['isArchived'] is bool ? map['isArchived'] as bool : false,
    );
  }

  static List<AgentMessage> _messages(Object? value) {
    if (value is! List) return const <AgentMessage>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(_messageFromMap)
        .whereType<AgentMessage>()
        .toList(growable: false);
  }

  static AgentMessage? _messageFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final role = _enumValue(MessageRole.values, map['role'], null);
    final content = map['content'];
    final createdAt = _date(map['createdAt']);
    if (id is! String ||
        role == null ||
        content is! String ||
        createdAt == null) {
      return null;
    }
    return AgentMessage(
      id: id,
      role: role,
      content: content,
      createdAt: createdAt,
      status:
          _enumValue(
            MessageStatus.values,
            map['status'],
            MessageStatus.complete,
          ) ??
          MessageStatus.complete,
      reasoning: map['reasoning'] is String ? map['reasoning'] as String : '',
      events: _events(map['events']),
      isFinalAnswer: map['isFinalAnswer'] is bool
          ? map['isFinalAnswer'] as bool
          : true,
    );
  }

  static List<AgentEvent> _events(Object? value) {
    if (value is! List) return const <AgentEvent>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(_eventFromMap)
        .whereType<AgentEvent>()
        .toList(growable: false);
  }

  static AgentEvent? _eventFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    final kind = _enumValue(AgentEventKind.values, map['kind'], null);
    if (id is! String || title is! String || kind == null) return null;
    return AgentEvent(
      id: id,
      kind: kind,
      title: title,
      detail: map['detail'] is String ? map['detail'] as String : '',
      status:
          _enumValue(
            AgentEventStatus.values,
            map['status'],
            AgentEventStatus.running,
          ) ??
          AgentEventStatus.running,
      additions: _nullableInt(map['additions']),
      deletions: _nullableInt(map['deletions']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static T? _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    T? fallback,
  ) {
    if (value is! String) return fallback;
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
    return fallback;
  }
}
