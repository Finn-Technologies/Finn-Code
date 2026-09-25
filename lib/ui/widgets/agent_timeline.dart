import 'package:flutter/material.dart';

import '../../domain/models/agent_event.dart';

class AgentTimeline extends StatelessWidget {
  const AgentTimeline({super.key, required this.events});

  final List<AgentEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < events.length; index++)
            _TimelineRow(
              event: events[index],
              colors: Theme.of(context).colorScheme,
              showLine: index != events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.colors,
    required this.showLine,
  });

  final AgentEvent event;
  final ColorScheme colors;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.status, colors);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 28,
            child: Column(
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_eventIcon(event.kind), size: 14, color: color),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 13 : 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (event.kind == AgentEventKind.diff &&
                          (event.additions != null || event.deletions != null))
                        Text(
                          '+${event.additions ?? 0}  −${event.deletions ?? 0}',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            color: colors.tertiary,
                          ),
                        ),
                    ],
                  ),
                  if (event.detail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      event.detail,
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: event.kind == AgentEventKind.command
                            ? 'JetBrainsMono'
                            : 'Inter',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(AgentEventStatus status, ColorScheme colors) =>
      switch (status) {
        AgentEventStatus.queued => colors.primary,
        AgentEventStatus.running => colors.primary,
        AgentEventStatus.completed => colors.tertiary,
        AgentEventStatus.failed => colors.error,
        AgentEventStatus.declined => colors.tertiary,
      };

  IconData _eventIcon(AgentEventKind kind) => switch (kind) {
    AgentEventKind.status => Icons.check_rounded,
    AgentEventKind.reasoning => Icons.psychology_alt_outlined,
    AgentEventKind.tool => Icons.build_outlined,
    AgentEventKind.fileChange => Icons.edit_note_rounded,
    AgentEventKind.command => Icons.terminal_rounded,
    AgentEventKind.diff => Icons.difference_outlined,
    AgentEventKind.error => Icons.error_outline_rounded,
  };
}
