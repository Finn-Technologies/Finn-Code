import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/agent_session.dart';
import '../../../domain/models/agent_stream_update.dart';
import '../../../domain/models/provider_config.dart';
import '../../../viewmodels/app_view_model.dart';
import '../../widgets/agent_composer.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/provider_badge.dart';
import '../../widgets/provider_editor_sheet.dart';
import '../../widgets/session_runtime_sheet.dart';
import '../../widgets/runtime_badge.dart';
import '../../widgets/status_dot.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SessionPane(showBackButton: Navigator.canPop(context)),
    );
  }
}

class SessionPane extends StatefulWidget {
  const SessionPane({super.key, this.showBackButton = false});

  final bool showBackButton;

  @override
  State<SessionPane> createState() => _SessionPaneState();
}

class _SessionPaneState extends State<SessionPane> {
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  int _lastContentLength = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScroll(int messageCount, int contentLength) {
    if (messageCount == _lastMessageCount &&
        contentLength == _lastContentLength) {
      return;
    }
    _lastMessageCount = messageCount;
    _lastContentLength = contentLength;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        final session = state.selectedSession;
        if (session == null) return const _NoSession();
        final provider =
            viewModel.providersForId(session.providerId) ??
            state.selectedProvider;
        final contentLength = session.messages.fold<int>(
          0,
          (sum, message) => sum + message.content.length,
        );
        _scheduleScroll(session.messages.length, contentLength);
        final isPhone = MediaQuery.sizeOf(context).width < 700;

        return SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _SessionHeader(
                session: session,
                provider: provider,
                connected: state.connectedProviderIds.contains(provider.id),
                showBackButton: widget.showBackButton,
                isPhone: isPhone,
              ),
              if (state.errorMessage != null)
                _InlineError(
                  message: state.errorMessage!,
                  canRetry: session.status == SessionStatus.failed,
                  onRetry: viewModel.retrySelectedSession,
                ),
              Expanded(
                child: session.messages.isEmpty
                    ? const _EmptySession()
                    : ListView.builder(
                        key: const Key('session-message-list'),
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          isPhone ? 14 : 28,
                          20,
                          isPhone ? 14 : 28,
                          28,
                        ),
                        itemCount: session.messages.length,
                        itemBuilder: (context, index) => Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: MessageBubble(
                              key: ValueKey(session.messages[index].id),
                              message: session.messages[index],
                            ),
                          ),
                        ),
                      ),
              ),
              if (state.pendingApproval != null)
                _ApprovalBar(
                  request: state.pendingApproval!,
                  queueLength: state.approvalsForSession(session.id).length,
                  isResolving: state.isResolvingApproval(session.id),
                  onDecision: viewModel.resolveApproval,
                ),
              AgentComposer(
                isSending: state.isSending,
                provider: provider,
                connected: state.connectedProviderIds.contains(provider.id),
                onSend: viewModel.sendMessage,
                onCancel: viewModel.cancelRun,
                onProviderTap: () => showSessionRuntimePicker(
                  context,
                  sessionId: session.id,
                  current: provider,
                  onConfigure: () =>
                      showProviderEditor(context, provider: provider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.provider,
    required this.connected,
    required this.showBackButton,
    required this.isPhone,
  });

  final AgentSession session;
  final ProviderConfig provider;
  final bool connected;
  final bool showBackButton;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showBackButton)
                IconButton(
                  tooltip: 'Back to tasks',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              else
                const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        StatusDot(status: session.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (session.projectPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 17, top: 3),
                        child: Text(
                          session.projectPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontFamily: 'JetBrainsMono',
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isPhone)
                ProviderBadge(provider: provider, connected: connected),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Task actions',
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'pin',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        session.isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                      ),
                      title: Text(session.isPinned ? 'Unpin task' : 'Pin task'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'archive',
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
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded),
                      title: const Text('Delete task'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isPhone) ...<Widget>[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ProviderBadge(provider: provider, connected: connected),
                const SizedBox(height: 6),
                RuntimeBadge(state: context.read<AppViewModel>().state),
              ],
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: RuntimeBadge(state: context.read<AppViewModel>().state),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final viewModel = context.read<AppViewModel>();
    if (action == 'pin') {
      viewModel.setSessionPinned(session.id, isPinned: !session.isPinned);
      return;
    }
    if (action == 'archive') {
      viewModel.setSessionArchived(session.id, isArchived: !session.isArchived);
      if (!session.isArchived && Navigator.canPop(context)) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    if (action == 'delete') {
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
      if (shouldDelete == true) {
        viewModel.deleteSession(session.id);
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.of(context).maybePop();
        }
      }
    }
  }
}

class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({
    required this.request,
    required this.queueLength,
    required this.isResolving,
    required this.onDecision,
  });

  final ApprovalRequest request;
  final int queueLength;
  final bool isResolving;
  final Future<void> Function({
    required bool approve,
    required bool allowForSession,
  })
  onDecision;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.shield_outlined, color: colors.onTertiaryContainer),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  queueLength > 1
                      ? '${request.title} · 1 of $queueLength'
                      : request.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (isResolving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (request.detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              request.detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onTertiaryContainer,
              ),
            ),
          ],
          if ((request.command ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                request.command!,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                key: const Key('approve-once-button'),
                onPressed: isResolving
                    ? null
                    : () => onDecision(approve: true, allowForSession: false),
                child: const Text('Approve once'),
              ),
              OutlinedButton(
                key: const Key('approve-session-button'),
                onPressed: isResolving
                    ? null
                    : () => onDecision(approve: true, allowForSession: true),
                child: const Text('Allow for session'),
              ),
              TextButton(
                key: const Key('deny-approval-button'),
                onPressed: isResolving
                    ? null
                    : () => onDecision(approve: false, allowForSession: false),
                child: const Text('Deny'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    this.canRetry = false,
    this.onRetry,
  });

  final String message;
  final bool canRetry;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onErrorContainer),
              ),
            ),
            if (canRetry && onRetry != null)
              TextButton(
                key: const Key('retry-task-button'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: context.read<AppViewModel>().clearError,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.forum_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
            'Create a task to begin',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _EmptySession extends StatelessWidget {
  const _EmptySession();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 29,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Start with a clear request',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Describe the outcome, include relevant context, and let the agent work through the task with you.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const <Widget>[
                  _PromptChip(
                    icon: Icons.bug_report_outlined,
                    label: 'Find a bug',
                  ),
                  _PromptChip(
                    icon: Icons.auto_fix_high_outlined,
                    label: 'Fix an issue',
                  ),
                  _PromptChip(
                    icon: Icons.science_outlined,
                    label: 'Explain code',
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

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(width: 7),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
