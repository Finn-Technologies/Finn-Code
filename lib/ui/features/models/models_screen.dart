import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_shape.dart';
import '../../../domain/models/provider_config.dart';
import '../../../viewmodels/app_view_model.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/provider_badge.dart';
import '../../widgets/provider_editor_sheet.dart';
import '../../widgets/section_header.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        final selected = state.selectedProvider;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: <Widget>[
                        const BrandMark(showWordmark: true),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: () => showProviderEditor(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add provider'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: _FreeModelCallout(
                      onUseOnDevice: () => _useProvider(
                        context,
                        viewModel,
                        'android-on-device',
                        test: true,
                      ),
                      onUseSpaceBunny: () => _useProvider(
                        context,
                        viewModel,
                        'space-bunny-free',
                        test: false,
                      ),
                      onUseLocal: () => _useProvider(
                        context,
                        viewModel,
                        'llama-cpp-local',
                        test: false,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Runtimes',
                      subtitle:
                          'Choose where the agent thinks and which workspace it can use.',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.crossAxisExtent < 600;
                      if (isCompact) {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final provider = state.providers[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ProviderListTile(
                                provider: provider,
                                selected: provider.id == selected.id,
                                connected: state.connectedProviderIds.contains(
                                  provider.id,
                                ),
                                busy: state.busyProviderIds.contains(
                                  provider.id,
                                ),
                                onTap: () => _useProvider(
                                  context,
                                  viewModel,
                                  provider.id,
                                ),
                                onEdit: () => showProviderEditor(
                                  context,
                                  provider: provider,
                                ),
                              ),
                            );
                          }, childCount: state.providers.length),
                        );
                      }
                      final columns = constraints.crossAxisExtent >= 900
                          ? 3
                          : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 156,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final provider = state.providers[index];
                          return _ProviderCard(
                            provider: provider,
                            selected: provider.id == selected.id,
                            connected: state.connectedProviderIds.contains(
                              provider.id,
                            ),
                            busy: state.busyProviderIds.contains(provider.id),
                            onTap: () =>
                                _useProvider(context, viewModel, provider.id),
                            onEdit: () =>
                                showProviderEditor(context, provider: provider),
                          );
                        }, childCount: state.providers.length),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Models',
                      subtitle: state.models.isEmpty
                          ? 'Discover models from ${selected.name}.'
                          : '${state.models.length} models discovered.',
                      trailing: IconButton(
                        tooltip: 'Refresh models',
                        onPressed: state.busyProviderIds.contains(selected.id)
                            ? null
                            : viewModel.refreshModels,
                        icon: state.busyProviderIds.contains(selected.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: _ModelList(provider: selected, viewModel: viewModel),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _useProvider(
    BuildContext context,
    AppViewModel viewModel,
    String providerId, {
    bool test = false,
  }) {
    viewModel.selectProvider(providerId);
    final provider = viewModel.providersForId(providerId);
    if (test) {
      viewModel.testProvider(providerId);
      return;
    }
    if (provider != null && _supportsDiscovery(provider)) {
      viewModel.refreshModels();
    }
  }

  bool _supportsDiscovery(ProviderConfig provider) =>
      provider.protocol == ProviderProtocol.openAICompatible ||
      provider.protocol == ProviderProtocol.anthropic ||
      provider.protocol == ProviderProtocol.gemini ||
      provider.protocol == ProviderProtocol.codex;
}

class _ProviderListTile extends StatelessWidget {
  const _ProviderListTile({
    required this.provider,
    required this.selected,
    required this.connected,
    required this.busy,
    required this.onTap,
    required this.onEdit,
  });

  final ProviderConfig provider;
  final bool selected;
  final bool connected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.72)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.controlRadius,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.controlRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 7, 12),
          child: Row(
            children: <Widget>[
              ProviderBadge(provider: provider, compact: true),
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
                      provider.description.isEmpty
                          ? provider.protocol.label
                          : provider.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: <Widget>[
                        if (provider.isFreeTier)
                          _FreePill(colors: colors)
                        else
                          Text(
                            provider.protocol.shortLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        if (connected) ...<Widget>[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: colors.tertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Ready',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.tertiary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Edit ${provider.name}',
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeModelCallout extends StatelessWidget {
  const _FreeModelCallout({
    required this.onUseOnDevice,
    required this.onUseSpaceBunny,
    required this.onUseLocal,
  });

  final VoidCallback onUseOnDevice;
  final VoidCallback onUseSpaceBunny;
  final VoidCallback onUseLocal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.science_outlined, color: colors.onTertiaryContainer),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Try a live model',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Space Bunny is a keyless hosted route for quick turns. Use the Android harness when a task needs local workspace tools.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onTertiaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onUseOnDevice,
                icon: const Icon(Icons.android_rounded, size: 18),
                label: const Text('Use Android harness'),
              ),
              FilledButton.tonalIcon(
                onPressed: onUseSpaceBunny,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: const Text('Try Space Bunny'),
              ),
              OutlinedButton.icon(
                onPressed: onUseLocal,
                icon: const Icon(Icons.memory_rounded, size: 18),
                label: const Text('Use local model'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.selected,
    required this.connected,
    required this.busy,
    required this.onTap,
    required this.onEdit,
  });

  final ProviderConfig provider;
  final bool selected;
  final bool connected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.72)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.controlRadius,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.controlRadius,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ProviderBadge(provider: provider, compact: true),
                  const Spacer(),
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit ${provider.name}',
                      onPressed: onEdit,
                      icon: const Icon(Icons.tune_rounded, size: 19),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                provider.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  provider.description.isEmpty
                      ? provider.protocol.label
                      : provider.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  if (provider.isFreeTier)
                    _FreePill(colors: colors)
                  else
                    Text(
                      provider.protocol.shortLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  if (connected)
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colors.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreePill extends StatelessWidget {
  const _FreePill({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'FREE',
        style: TextStyle(
          color: colors.onTertiaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  const _ModelList({required this.provider, required this.viewModel});

  final ProviderConfig provider;
  final AppViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final models = viewModel.state.models;
    if (models.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: AppShape.surfaceRadius,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              provider.model.isEmpty
                  ? 'No model selected.'
                  : 'Current model: ${provider.model}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (provider.requiresApiKey && provider.apiKey.isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text('Add a provider key to discover live models.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    showProviderEditor(context, provider: provider),
                child: const Text('Configure provider'),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: viewModel.refreshModels,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Discover models'),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: AppShape.surfaceRadius,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < models.length; index++) ...<Widget>[
            ListTile(
              title: Text(models[index].displayName),
              subtitle: Text(
                models[index].id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                ),
              ),
              trailing: provider.model == models[index].id
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => viewModel.updateProvider(
                provider.copyWith(model: models[index].id),
              ),
            ),
            if (index != models.length - 1)
              const Divider(indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}
