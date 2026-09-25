import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_shape.dart';
import '../../../domain/models/agent_session.dart';
import '../../../domain/models/provider_config.dart';
import '../../../viewmodels/app_view_model.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/provider_badge.dart';
import '../../widgets/runtime_badge.dart';
import '../../widgets/status_dot.dart';
import '../session/session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                children: <Widget>[
                  SizedBox(
                    width: 344,
                    child: _TaskSidebar(
                      query: _query,
                      showArchived: _showArchived,
                      onQueryChanged: (value) => setState(() => _query = value),
                      onArchivedChanged: (value) =>
                          setState(() => _showArchived = value),
                      searchController: _searchController,
                      onCreate: () => _createTask(context, viewModel),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const Expanded(child: SessionPane()),
                ],
              );
            }
            return _TaskSidebar(
              query: _query,
              showArchived: _showArchived,
              onQueryChanged: (value) => setState(() => _query = value),
              onArchivedChanged: (value) =>
                  setState(() => _showArchived = value),
              searchController: _searchController,
              onCreate: () => _createTask(context, viewModel),
              mobile: true,
            );
          },
        );
      },
    );
  }

  Future<void> _createTask(BuildContext context, AppViewModel viewModel) async {
    final provider = viewModel.state.selectedProvider;
    final projectPath = await showDialog<String>(
      context: context,
      builder: (context) => _NewTaskDialog(provider: provider),
    );
    if (projectPath == null || !context.mounted) return;
    final id = viewModel.createSession(projectPath: projectPath.trim());
    if (MediaQuery.sizeOf(context).width < 900) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const SessionScreen()),
      );
    } else {
      viewModel.selectSession(id);
    }
  }
}

class _TaskSidebar extends StatelessWidget {
  const _TaskSidebar({
    required this.query,
    required this.showArchived,
    required this.onQueryChanged,
    required this.onArchivedChanged,
    required this.searchController,
    required this.onCreate,
    this.mobile = false,
  });

  final String query;
  final bool showArchived;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onArchivedChanged;
  final TextEditingController searchController;
  final VoidCallback onCreate;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        final normalizedQuery = query.trim().toLowerCase();
        final sessions =
            state.sessions
                .where((session) {
                  if (session.isArchived != showArchived) return false;
                  if (normalizedQuery.isEmpty) return true;
                  return session.title.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                      session.preview.toLowerCase().contains(normalizedQuery) ||
                      session.model.toLowerCase().contains(normalizedQuery);
                })
                .toList(growable: false)
              ..sort((a, b) {
                if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
                return b.updatedAt.compareTo(a.updatedAt);
              });
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: SafeArea(
            bottom: mobile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: <Widget>[
                      const BrandMark(showWordmark: true),
                      const Spacer(),
                      IconButton.filled(
                        key: const Key('new-task-button'),
                        tooltip: 'New task',
                        onPressed: onCreate,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: RuntimeBadge(state: state),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: TextField(
                    key: const Key('task-search-field'),
                    controller: searchController,
                    onChanged: onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search tasks',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Text(
                        showArchived ? 'Archive' : 'Tasks',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountPill(count: sessions.length),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => onArchivedChanged(!showArchived),
                        icon: Icon(
                          showArchived
                              ? Icons.inventory_2_outlined
                              : Icons.inventory_2_rounded,
                          size: 17,
                        ),
                        label: Text(showArchived ? 'Active' : 'Archive'),
                      ),
                    ],
                  ),
                ),
                if (sessions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${_activeCount(state.sessions)} active · ${_runningCount(state)} running',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: sessions.isEmpty
                      ? _EmptyTasks(query: query, showArchived: showArchived)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final provider =
                                viewModel.providersForId(session.providerId) ??
                                state.selectedProvider;
                            return _TaskTile(
                              session: session,
                              provider: provider,
                              selected: session.id == state.selectedSessionId,
                              onTap: () {
                                viewModel.selectSession(session.id);
                                if (mobile) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) =>
                                          const SessionScreen(),
                                    ),
                                  );
                                }
                              },
                              onAction: (action) {
                                switch (action) {
                                  case _TaskAction.pin:
                                    viewModel.setSessionPinned(
                                      session.id,
                                      isPinned: !session.isPinned,
                                    );
                                  case _TaskAction.archive:
                                    viewModel.setSessionArchived(
                                      session.id,
                                      isArchived: !session.isArchived,
                                    );
                                  case _TaskAction.delete:
                                    _confirmDelete(context, viewModel, session);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _activeCount(List<AgentSession> sessions) =>
      sessions.where((session) => !session.isArchived).length;

  int _runningCount(AppState state) => state.sessions
      .where((session) => state.isSessionSending(session.id))
      .length;

  Future<void> _confirmDelete(
    BuildContext context,
    AppViewModel viewModel,
    AgentSession session,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('This removes “${session.title}” from this device.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) viewModel.deleteSession(session.id);
  }
}

enum _TaskAction { pin, archive, delete }

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.session,
    required this.provider,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final AgentSession session;
  final ProviderConfig provider;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_TaskAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey<String>('session-tile-${session.id}'),
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.7)
            : colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: AppShape.controlRadius,
          side: BorderSide(
            color: selected
                ? colors.primary.withValues(alpha: 0.58)
                : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppShape.controlRadius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: StatusDot(status: session.status, size: 9),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          if (session.isPinned) ...<Widget>[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          Text(
                            _relativeTime(session.updatedAt),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        session.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: <Widget>[
                          ProviderBadge(provider: provider, compact: true),
                          const Spacer(),
                          _StatusLabel(status: session.status),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_TaskAction>(
                  tooltip: 'Task actions',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  onSelected: onAction,
                  itemBuilder: (context) => <PopupMenuEntry<_TaskAction>>[
                    PopupMenuItem<_TaskAction>(
                      value: _TaskAction.pin,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          session.isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin_rounded,
                        ),
                        title: Text(
                          session.isPinned ? 'Unpin task' : 'Pin task',
                        ),
                      ),
                    ),
                    PopupMenuItem<_TaskAction>(
                      value: _TaskAction.archive,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          session.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        title: Text(
                          session.isArchived ? 'Restore task' : 'Archive task',
                        ),
                      ),
                    ),
                    if (!session.isArchived) const PopupMenuDivider(),
                    if (!session.isArchived)
                      PopupMenuItem<_TaskAction>(
                        value: _TaskAction.delete,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text('Delete task'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return DateFormat.MMMd().format(value);
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (status) {
      SessionStatus.running => 'Running',
      SessionStatus.waitingApproval => 'Needs approval',
      SessionStatus.failed => 'Failed',
      SessionStatus.idle => 'Ready',
    };
    final color = switch (status) {
      SessionStatus.running => colors.primary,
      SessionStatus.waitingApproval => colors.tertiary,
      SessionStatus.failed => colors.error,
      SessionStatus.idle => colors.onSurfaceVariant,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          status == SessionStatus.running
              ? Icons.sync_rounded
              : status == SessionStatus.waitingApproval
              ? Icons.shield_outlined
              : status == SessionStatus.failed
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NewTaskDialog extends StatefulWidget {
  const _NewTaskDialog({required this.provider});

  final ProviderConfig provider;

  @override
  State<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<_NewTaskDialog> {
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCodex = widget.provider.protocol == ProviderProtocol.codex;
    return AlertDialog(
      title: const Text('Start a coding task'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Runtime: ${widget.provider.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              autofocus: isCodex,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Project path on the runtime host',
                hintText: isCodex ? '/Users/you/project' : 'Optional',
                helperText: isCodex
                    ? 'Leave blank for read-only Codex mode.'
                    : 'Direct API modes stay chat-only.',
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_pathController.text),
          child: const Text('Create task'),
        ),
      ],
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.query, required this.showArchived});

  final String query;
  final bool showArchived;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              showArchived
                  ? Icons.inventory_2_outlined
                  : Icons.search_off_rounded,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              showArchived
                  ? 'No archived tasks'
                  : query.isEmpty
                  ? 'No tasks yet'
                  : 'No matching tasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              showArchived
                  ? 'Archived tasks stay available without taking over your active list.'
                  : query.isEmpty
                  ? 'Create a task to start a focused agent run.'
                  : 'Try a different title, model, or prompt.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
