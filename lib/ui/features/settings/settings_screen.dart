import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_shape.dart';
import '../../../domain/models/provider_config.dart';
import '../../../viewmodels/app_view_model.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/provider_editor_sheet.dart';
import '../../widgets/section_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        final selected = state.selectedProvider;
        final customProviders = state.providers
            .where((provider) => !provider.isBuiltIn)
            .toList(growable: false);
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            bottom: false,
            child: ListView(
              key: const Key('settings-list'),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    BrandMark(showWordmark: true),
                    Spacer(),
                    Text('Settings'),
                  ],
                ),
                const SizedBox(height: 28),
                const SectionHeader(
                  title: 'Appearance',
                  subtitle:
                      'Finn Code follows your Android system theme by default.',
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: <ThemeMode>{state.themeMode},
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      viewModel.setThemeMode(selection.first),
                ),
                const SizedBox(height: 30),
                const SectionHeader(
                  title: 'Runtime',
                  subtitle:
                      'The default harness owns a private workspace on this device.',
                ),
                const SizedBox(height: 12),
                _AndroidRuntimeCard(
                  state: state,
                  onRefresh: viewModel.refreshRuntime,
                ),
                const SizedBox(height: 10),
                _RemoteCodexCard(
                  provider: state.providers.firstWhere(
                    (provider) => provider.id == 'codex-gateway',
                  ),
                ),
                const SizedBox(height: 30),
                const SectionHeader(
                  title: 'Default provider',
                  subtitle:
                      'New tasks use this runtime and model unless you change them in the task.',
                ),
                const SizedBox(height: 12),
                _SelectedProviderCard(
                  provider: selected,
                  onEdit: () => showProviderEditor(context, provider: selected),
                  onSelect: viewModel.selectProvider,
                  providers: state.providers,
                ),
                if (customProviders.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 26),
                  const SectionHeader(title: 'Custom providers'),
                  const SizedBox(height: 8),
                  for (final provider in customProviders)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      title: Text(provider.name),
                      subtitle: Text(provider.protocol.label),
                      trailing: IconButton(
                        tooltip: 'Delete ${provider.name}',
                        onPressed: () => viewModel.removeProvider(provider.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                ],
                const SizedBox(height: 30),
                const SectionHeader(
                  title: 'Safety',
                  subtitle: 'Secrets and tool permissions stay explicit.',
                ),
                const SizedBox(height: 12),
                const _InfoPanel(
                  icon: Icons.key_rounded,
                  title: 'Provider secrets',
                  detail:
                      'API keys use Android secure storage and are never written into task history.',
                ),
                const SizedBox(height: 9),
                const _InfoPanel(
                  icon: Icons.shield_outlined,
                  title: 'Approval-gated tools',
                  detail:
                      'Codex command and file-change requests pause until you approve or deny them in the task.',
                ),
                const SizedBox(height: 9),
                const _InfoPanel(
                  icon: Icons.lock_outline_rounded,
                  title: 'Local workspace boundary',
                  detail:
                      'The Android runtime can only read and write its app-private workspace. External paths are rejected.',
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Finn Code · Android first',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AndroidRuntimeCard extends StatelessWidget {
  const _AndroidRuntimeCard({required this.state, required this.onRefresh});

  final AppState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            state.runtimeReady
                ? Icons.android_rounded
                : Icons.error_outline_rounded,
            color: state.runtimeReady ? colors.tertiary : colors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.runtimeReady
                      ? 'Android runtime active'
                      : 'Android runtime unavailable',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  state.runtimeReady
                      ? '${state.runtimeName} · ${state.runtimeWorkspace}'
                      : (state.runtimeError ??
                            'The local bridge did not respond.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (state.runtimePath.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    state.runtimePath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh runtime',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _RemoteCodexCard extends StatelessWidget {
  const _RemoteCodexCard({required this.provider});

  final ProviderConfig provider;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.laptop_mac_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Remote Codex Gateway',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Optional app-server connection for tools and approvals.',
                ),
                const SizedBox(height: 4),
                Text(
                  provider.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showProviderEditor(context, provider: provider),
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }
}

class _SelectedProviderCard extends StatelessWidget {
  const _SelectedProviderCard({
    required this.provider,
    required this.onEdit,
    required this.onSelect,
    required this.providers,
  });

  final ProviderConfig provider;
  final VoidCallback onEdit;
  final ValueChanged<String> onSelect;
  final List<ProviderConfig> providers;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: provider.id,
            decoration: const InputDecoration(labelText: 'Default provider'),
            items: providers
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onSelect(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      provider.model.isEmpty
                          ? 'Model discovered at runtime'
                          : provider.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider.protocol.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 21, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.surfaceRadius,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
