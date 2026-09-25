import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/provider_config.dart';
import '../../viewmodels/app_view_model.dart';

Future<void> showSessionRuntimePicker(
  BuildContext context, {
  required String sessionId,
  required ProviderConfig current,
  VoidCallback? onConfigure,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SessionRuntimeSheet(
      sessionId: sessionId,
      current: current,
      onConfigure: onConfigure,
    ),
  );
}

class _SessionRuntimeSheet extends StatelessWidget {
  const _SessionRuntimeSheet({
    required this.sessionId,
    required this.current,
    this.onConfigure,
  });

  final String sessionId;
  final ProviderConfig current;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AppViewModel>();
    final providers = viewModel.state.providers;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Task runtime',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the model and tools for this task only.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: providers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final provider = providers[index];
                final selected = provider.id == current.id;
                return Material(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () {
                      viewModel.setSessionProvider(sessionId, provider.id);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _iconFor(provider.protocol),
                            color: selected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  provider.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  provider.model.isEmpty
                                      ? provider.protocol.label
                                      : provider.model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        fontFamily: provider.model.isEmpty
                                            ? null
                                            : 'JetBrainsMono',
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onConfigure?.call();
            },
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Configure selected runtime'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ProviderProtocol protocol) => switch (protocol) {
    ProviderProtocol.demo => Icons.auto_awesome_rounded,
    ProviderProtocol.onDevice => Icons.android_rounded,
    ProviderProtocol.openAICompatible => Icons.hub_outlined,
    ProviderProtocol.anthropic => Icons.blur_on_rounded,
    ProviderProtocol.gemini => Icons.diamond_outlined,
    ProviderProtocol.codex => Icons.code_rounded,
  };
}
