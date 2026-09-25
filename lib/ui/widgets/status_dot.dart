import 'package:flutter/material.dart';

import '../../domain/models/agent_session.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 8});

  final SessionStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (status) {
      SessionStatus.running => colors.primary,
      SessionStatus.waitingApproval => colors.tertiary,
      SessionStatus.failed => colors.error,
      SessionStatus.idle => colors.tertiary,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
