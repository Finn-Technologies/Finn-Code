import 'package:flutter/material.dart';

import '../../domain/models/provider_config.dart';

class AgentComposer extends StatefulWidget {
  const AgentComposer({
    super.key,
    required this.isSending,
    required this.provider,
    this.connected = false,
    required this.onSend,
    required this.onCancel,
    this.onProviderTap,
  });

  final bool isSending;
  final ProviderConfig provider;
  final bool connected;
  final Future<bool> Function(String prompt) onSend;
  final VoidCallback onCancel;
  final VoidCallback? onProviderTap;

  @override
  State<AgentComposer> createState() => _AgentComposerState();
}

class _AgentComposerState extends State<AgentComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.isSending) return;
    _controller.clear();
    final sent = await widget.onSend(value);
    if (sent && mounted) _focusNode.requestFocus();
    if (!sent && mounted) {
      _controller.text = value;
      _controller.selection = TextSelection.collapsed(offset: value.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _RuntimeContext(
                      provider: widget.provider,
                      connected: widget.connected,
                      onTap: widget.onProviderTap,
                    ),
                  ),
                  if (widget.onProviderTap != null)
                    IconButton(
                      tooltip: 'Change model or runtime',
                      onPressed: widget.isSending ? null : widget.onProviderTap,
                      icon: const Icon(Icons.tune_rounded, size: 19),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Workspace context',
                      onPressed: widget.isSending
                          ? null
                          : () => _showProjectHint(context),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('agent-prompt-field'),
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !widget.isSending,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Describe a coding task…',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.isSending)
                      IconButton.filled(
                        key: const Key('cancel-run-button'),
                        tooltip: 'Stop run',
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.stop_rounded),
                      )
                    else
                      IconButton.filled(
                        key: const Key('send-prompt-button'),
                        tooltip: 'Send',
                        onPressed: _send,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProjectHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Project paths are configured when creating a Codex task. Direct API modes are chat-only.',
        ),
      ),
    );
  }
}

class _RuntimeContext extends StatelessWidget {
  const _RuntimeContext({
    required this.provider,
    required this.connected,
    this.onTap,
  });

  final ProviderConfig provider;
  final bool connected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Row(
      children: <Widget>[
        Icon(_iconFor(provider.protocol), size: 17, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                provider.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                provider.model.isEmpty
                    ? provider.protocol.shortLabel
                    : provider.model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFamily: provider.model.isEmpty ? null : 'JetBrainsMono',
                ),
              ),
            ],
          ),
        ),
        if (connected)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.tertiary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
    return Semantics(
      button: onTap != null,
      label: 'Runtime ${provider.name}. ${connected ? 'Ready' : 'Not tested'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
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
