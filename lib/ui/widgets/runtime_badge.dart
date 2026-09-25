import 'package:flutter/material.dart';

import '../../core/theme/app_shape.dart';
import '../../viewmodels/app_view_model.dart';

class RuntimeBadge extends StatelessWidget {
  const RuntimeBadge({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = state.runtimeReady;
    return Semantics(
      container: true,
      label: ready
          ? 'Android runtime ready. Workspace ${state.runtimeWorkspace}.'
          : 'Android runtime unavailable. ${state.runtimeError ?? ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: ready
              ? colors.tertiaryContainer.withValues(alpha: 0.72)
              : colors.errorContainer,
          borderRadius: AppShape.controlRadius,
          border: Border.all(color: ready ? colors.tertiary : colors.error),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              ready ? Icons.android_rounded : Icons.error_outline_rounded,
              size: 16,
              color: ready
                  ? colors.onTertiaryContainer
                  : colors.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Text(
              ready ? 'On Android' : 'Runtime offline',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ready
                    ? colors.onTertiaryContainer
                    : colors.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
