import 'package:flutter/material.dart';

import '../../core/theme/app_shape.dart';
import '../../domain/models/provider_config.dart';

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({
    super.key,
    required this.provider,
    this.compact = false,
    this.connected = false,
  });

  final ProviderConfig provider;
  final bool compact;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: AppShape.controlRadius,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ProviderGlyph(protocol: provider.protocol, size: compact ? 15 : 17),
          if (!compact) ...<Widget>[
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                provider.name,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (connected) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderGlyph extends StatelessWidget {
  const _ProviderGlyph({required this.protocol, required this.size});

  final ProviderProtocol protocol;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (protocol) {
      ProviderProtocol.demo => Icons.auto_awesome_rounded,
      ProviderProtocol.onDevice => Icons.android_rounded,
      ProviderProtocol.openAICompatible => Icons.hub_outlined,
      ProviderProtocol.anthropic => Icons.blur_on_rounded,
      ProviderProtocol.gemini => Icons.diamond_outlined,
      ProviderProtocol.codex => Icons.code_rounded,
    };
    return Icon(icon, size: size, color: Theme.of(context).colorScheme.primary);
  }
}
