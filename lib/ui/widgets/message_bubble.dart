import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../domain/models/agent_message.dart';
import 'agent_timeline.dart';
import 'brand_mark.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == MessageRole.user) {
      return _UserMessage(message: message);
    }
    return _AssistantMessage(message: message);
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(
              16,
            ).copyWith(bottomRight: const Radius.circular(5)),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: SelectionArea(
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatefulWidget {
  const _AssistantMessage({required this.message});

  final AgentMessage message;

  @override
  State<_AssistantMessage> createState() => _AssistantMessageState();
}

class _AssistantMessageState extends State<_AssistantMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.message.status == MessageStatus.streaming) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AssistantMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasStreaming = oldWidget.message.status == MessageStatus.streaming;
    final isStreaming = widget.message.status == MessageStatus.streaming;
    if (!wasStreaming && isStreaming) {
      _controller.repeat(reverse: true);
    } else if (wasStreaming && !isStreaming) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final colorScheme = Theme.of(context).colorScheme;
    final isStreaming = message.status == MessageStatus.streaming;
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: BrandMark(size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('Finn', style: Theme.of(context).textTheme.labelLarge),
                    if (isStreaming) ...<Widget>[
                      const SizedBox(width: 8),
                      FadeTransition(
                        opacity: Tween<double>(begin: 0.35, end: 1).animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Text(
                          'working',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (message.content.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy response',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.content),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Response copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                  ],
                ),
                if (message.reasoning.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _ReasoningDisclosure(reasoning: message.reasoning),
                ],
                if (message.events.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  AgentTimeline(events: message.events),
                ],
                if (message.content.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  SelectionArea(
                    child: MarkdownBody(
                      data: message.content,
                      selectable: false,
                      styleSheet: _markdownStyle(context),
                    ),
                  ),
                ] else if (isStreaming) ...<Widget>[
                  const SizedBox(height: 14),
                  const _StreamingIndicator(),
                ],
                if (message.status == MessageStatus.error) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'This run ended with an error.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return base.copyWith(
      p: base.p?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15.5,
        height: 1.55,
      ),
      h1: base.h1?.copyWith(fontWeight: FontWeight.w700),
      h2: base.h2?.copyWith(fontWeight: FontWeight.w700),
      h3: base.h3?.copyWith(fontWeight: FontWeight.w600),
      code: base.code?.copyWith(
        fontFamily: 'JetBrainsMono',
        fontSize: 13,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      ),
      codeblockDecoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF09090B)
            : const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(15),
      ),
      codeblockPadding: const EdgeInsets.all(15),
      blockquoteDecoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      listBullet: base.listBullet?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _ReasoningDisclosure extends StatelessWidget {
  const _ReasoningDisclosure({required this.reasoning});

  final String reasoning;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        visualDensity: VisualDensity.compact,
        leading: Icon(
          Icons.psychology_alt_outlined,
          size: 19,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          'Reasoning',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              reasoning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingIndicator extends StatelessWidget {
  const _StreamingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: LinearProgressIndicator(
        minHeight: 3,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
