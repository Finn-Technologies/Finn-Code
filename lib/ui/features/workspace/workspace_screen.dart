import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_shape.dart';
import '../../../viewmodels/app_view_model.dart';
import '../../widgets/runtime_badge.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        final state = viewModel.state;
        if (!state.runtimeReady) return _WorkspaceUnavailable(state: state);
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return wide
                    ? _WideWorkspace(state: state)
                    : _CompactWorkspace(state: state);
              },
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceUnavailable extends StatelessWidget {
  const _WorkspaceUnavailable({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.smartphone_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Android runtime unavailable',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  state.runtimeError ?? 'The local bridge did not respond.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _WorkspaceTab { files, command }

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({required this.state});

  final AppState state;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  _WorkspaceTab _tab = _WorkspaceTab.files;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final viewModel = context.read<AppViewModel>();
    return ListView(
      key: const Key('workspace-list'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Workspace',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.runtimeWorkspace,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            RuntimeBadge(state: state),
          ],
        ),
        const SizedBox(height: 18),
        _WorkspaceToolbar(
          path: state.workspaceCurrentPath,
          onRoot: viewModel.navigateWorkspaceToRoot,
          onUp: viewModel.navigateWorkspaceUp,
          onRefresh: () =>
              viewModel.refreshWorkspaceFiles(path: state.workspaceCurrentPath),
          onNewFile: viewModel.createWorkspaceFile,
        ),
        const SizedBox(height: 12),
        SegmentedButton<_WorkspaceTab>(
          key: const Key('workspace-mode-switch'),
          segments: const <ButtonSegment<_WorkspaceTab>>[
            ButtonSegment<_WorkspaceTab>(
              value: _WorkspaceTab.files,
              icon: Icon(Icons.folder_open_rounded),
              label: Text('Files'),
            ),
            ButtonSegment<_WorkspaceTab>(
              value: _WorkspaceTab.command,
              icon: Icon(Icons.terminal_rounded),
              label: Text('Command'),
            ),
          ],
          selected: <_WorkspaceTab>{_tab},
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          onSelectionChanged: (selection) {
            setState(() => _tab = selection.first);
          },
        ),
        const SizedBox(height: 14),
        if (_tab == _WorkspaceTab.files) ...<Widget>[
          _WorkspaceFiles(state: state, compact: true),
          if (state.selectedWorkspacePath != null) ...<Widget>[
            const SizedBox(height: 14),
            _FileEditor(state: state, compact: true),
          ],
        ] else
          _CommandRunner(state: state),
      ],
    );
  }
}

class _WideWorkspace extends StatelessWidget {
  const _WideWorkspace({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AppViewModel>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Workspace',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.runtimeWorkspace,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              RuntimeBadge(state: state),
            ],
          ),
          const SizedBox(height: 20),
          _WorkspaceToolbar(
            path: state.workspaceCurrentPath,
            onRoot: viewModel.navigateWorkspaceToRoot,
            onUp: viewModel.navigateWorkspaceUp,
            onRefresh: () => viewModel.refreshWorkspaceFiles(
              path: state.workspaceCurrentPath,
            ),
            onNewFile: viewModel.createWorkspaceFile,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(flex: 5, child: _WorkspaceFiles(state: state)),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: state.selectedWorkspacePath == null
                      ? _CommandRunner(state: state)
                      : _FileEditor(state: state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceToolbar extends StatelessWidget {
  const _WorkspaceToolbar({
    required this.path,
    required this.onRoot,
    required this.onUp,
    required this.onRefresh,
    required this.onNewFile,
  });

  final String path;
  final VoidCallback onRoot;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onNewFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Workspace root',
          onPressed: onRoot,
          icon: const Icon(Icons.home_outlined),
        ),
        IconButton(
          tooltip: 'Up one folder',
          onPressed: path == '.' ? null : onUp,
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            path == '.' ? 'workspace /' : 'workspace / $path',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: 'Refresh workspace',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton.filledTonal(
          tooltip: 'New file',
          onPressed: onNewFile,
          icon: const Icon(Icons.note_add_rounded),
        ),
      ],
    );
  }
}

class _WorkspaceFiles extends StatelessWidget {
  const _WorkspaceFiles({required this.state, this.compact = false});

  final AppState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AppViewModel>();
    if (state.workspaceBusy && state.workspaceFiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.workspaceFiles.isEmpty) {
      return _Panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.folder_open_rounded,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'This workspace is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a file to start a local edit, or use a read-only command to inspect the runtime.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: state.workspaceBusy
                      ? null
                      : () => viewModel.createWorkspaceFile(),
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('New file'),
                ),
                OutlinedButton.icon(
                  onPressed: state.workspaceBusy
                      ? null
                      : () => viewModel.refreshWorkspaceFiles(
                          path: state.workspaceCurrentPath,
                        ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Directory',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${state.workspaceFiles.length} item${state.workspaceFiles.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (compact)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.workspaceFiles.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _fileTile(context, viewModel, index),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: state.workspaceFiles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _fileTile(context, viewModel, index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileTile(BuildContext context, AppViewModel viewModel, int index) {
    final file = state.workspaceFiles[index];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        file.isDirectory ? Icons.folder_rounded : _fileIcon(file.name),
        color: file.isDirectory
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(file.isDirectory ? 'Folder' : _formatBytes(file.size)),
      trailing: file.isDirectory
          ? const Icon(Icons.chevron_right_rounded, size: 19)
          : null,
      onTap: state.workspaceBusy
          ? null
          : file.isDirectory
          ? () => viewModel.refreshWorkspaceFiles(path: file.path)
          : () => viewModel.openWorkspaceFile(file.path),
    );
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.dart')) return Icons.code_rounded;
    if (lower.endsWith('.md')) return Icons.description_outlined;
    if (lower.endsWith('.json') || lower.endsWith('.yaml')) {
      return Icons.data_object_rounded;
    }
    if (lower.endsWith('.txt')) return Icons.notes_rounded;
    return Icons.insert_drive_file_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FileEditor extends StatefulWidget {
  const _FileEditor({required this.state, this.compact = false});

  final AppState state;
  final bool compact;

  @override
  State<_FileEditor> createState() => _FileEditorState();
}

class _FileEditorState extends State<_FileEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.workspaceFileContent,
    );
  }

  @override
  void didUpdateWidget(covariant _FileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedWorkspacePath !=
            widget.state.selectedWorkspacePath ||
        (!widget.state.workspaceDirty &&
            oldWidget.state.workspaceFileContent !=
                widget.state.workspaceFileContent)) {
      _controller.value = TextEditingValue(
        text: widget.state.workspaceFileContent,
        selection: TextSelection.collapsed(
          offset: widget.state.workspaceFileContent.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AppViewModel>();
    final state = widget.state;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      state.selectedWorkspacePath ?? 'File editor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.workspaceDirty
                          ? 'Unsaved changes'
                          : 'Saved on Android',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: state.workspaceDirty
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reset changes',
                onPressed: state.workspaceDirty && !state.workspaceBusy
                    ? viewModel.resetWorkspaceDraft
                    : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Delete file',
                onPressed: state.workspaceBusy
                    ? null
                    : () => _confirmDelete(context, viewModel, state),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              IconButton.filledTonal(
                key: const Key('workspace-save-file-button'),
                tooltip: 'Save on Android',
                onPressed:
                    state.workspaceBusy || state.selectedWorkspacePath == null
                    ? null
                    : () => viewModel.saveWorkspaceFile(
                        path: state.selectedWorkspacePath!,
                        content: _controller.text,
                      ),
                icon: const Icon(Icons.save_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.compact)
            SizedBox(
              height: 220,
              child: _buildEditor(context, viewModel, state),
            )
          else
            Expanded(child: _buildEditor(context, viewModel, state)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed:
                state.workspaceBusy || state.selectedWorkspacePath == null
                ? null
                : () => viewModel.saveWorkspaceFile(
                    path: state.selectedWorkspacePath!,
                    content: _controller.text,
                  ),
            icon: const Icon(Icons.save_rounded),
            label: Text(
              state.workspaceDirty ? 'Save changes' : 'Save on Android',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    AppViewModel viewModel,
    AppState state,
  ) {
    return TextField(
      key: const Key('workspace-editor-field'),
      controller: _controller,
      enabled: !state.workspaceBusy,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
      decoration: const InputDecoration(
        hintText: 'Write inside the Android workspace…',
        filled: true,
      ),
      onChanged: viewModel.updateWorkspaceDraft,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppViewModel viewModel,
    AppState state,
  ) async {
    final path = state.selectedWorkspacePath;
    if (path == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove $path from the Android workspace?'),
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
    if (shouldDelete == true) await viewModel.deleteWorkspaceFile(path);
  }
}

class _CommandRunner extends StatefulWidget {
  const _CommandRunner({required this.state});

  final AppState state;

  @override
  State<_CommandRunner> createState() => _CommandRunnerState();
}

class _CommandRunnerState extends State<_CommandRunner> {
  final TextEditingController _command = TextEditingController(text: 'ls');

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<AppViewModel>();
    final state = widget.state;
    return _Panel(
      key: const Key('workspace-command-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Run on Android',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state.workspaceCommandExitCode != null)
                _ExitCodePill(exitCode: state.workspaceCommandExitCode!),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Read-only commands run inside the app-private workspace. Shell write operations are blocked.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('workspace-command-field'),
                  controller: _command,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Command',
                    hintText: 'ls',
                  ),
                  onSubmitted: (value) => viewModel.runWorkspaceCommand(value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('workspace-run-command-button'),
                tooltip: 'Run command',
                onPressed: state.workspaceBusy
                    ? null
                    : () => viewModel.runWorkspaceCommand(_command.text),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final suggestion in const <String>[
                'ls',
                'pwd',
                'find .',
                'du',
              ])
                ActionChip(
                  label: Text(suggestion),
                  onPressed: state.workspaceBusy
                      ? null
                      : () {
                          _command.text = suggestion;
                          _command.selection = TextSelection.collapsed(
                            offset: suggestion.length,
                          );
                        },
                ),
            ],
          ),
          if (state.workspaceCommandOutput.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppShape.mediumRadius,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  state.workspaceCommandOutput,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExitCodePill extends StatelessWidget {
  const _ExitCodePill({required this.exitCode});

  final int exitCode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final success = exitCode == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: success ? colors.tertiaryContainer : colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        success ? 'exit 0' : 'exit $exitCode',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: success ? colors.onTertiaryContainer : colors.onErrorContainer,
          fontFamily: 'JetBrainsMono',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child});

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
