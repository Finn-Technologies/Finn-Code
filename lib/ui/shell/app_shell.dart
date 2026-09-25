import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/app_view_model.dart';
import '../features/home/home_screen.dart';
import '../features/models/models_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/workspace/workspace_screen.dart';
import '../widgets/brand_mark.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = <Widget>[
    HomeScreen(),
    WorkspaceScreen(),
    ModelsScreen(),
    SettingsScreen(),
  ];

  static const _destinations = <_AppDestination>[
    _AppDestination(
      label: 'Tasks',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
    ),
    _AppDestination(
      label: 'Workspace',
      icon: Icons.folder_open_outlined,
      selectedIcon: Icons.folder_open_rounded,
    ),
    _AppDestination(
      label: 'Models',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub_rounded,
    ),
    _AppDestination(
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        if (!viewModel.state.isInitialized) {
          return const _LaunchScreen();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final selectedIndex = viewModel.state.navigationIndex;
            final content = IndexedStack(
              index: selectedIndex,
              children: _screens,
            );
            if (constraints.maxWidth >= 760) {
              return Scaffold(
                body: Row(
                  children: <Widget>[
                    _WideNavigation(
                      selectedIndex: selectedIndex,
                      onSelected: viewModel.selectNavigation,
                    ),
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    Expanded(child: content),
                  ],
                ),
              );
            }
            return Scaffold(
              body: content,
              bottomNavigationBar: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: viewModel.selectNavigation,
                destinations: <NavigationDestination>[
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _WideNavigation extends StatelessWidget {
  const _WideNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 216,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 26),
                child: BrandMark(size: 36, showWordmark: false),
              ),
              for (
                var index = 0;
                index < AppShell._destinations.length;
                index++
              )
                _WideNavigationItem(
                  destination: AppShell._destinations[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Local-first runtime',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideNavigationItem extends StatelessWidget {
  const _WideNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: <Widget>[
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    destination.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandMark(size: 52, showWordmark: true),
            const SizedBox(height: 22),
            SizedBox(
              width: 112,
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Preparing your workspace',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
