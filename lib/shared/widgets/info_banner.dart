import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_badge.dart';

/// Inline notice with an icon, so meaning never relies on color alone.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final BadgeTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (tone) {
      BadgeTone.highlight => p.accentText,
      BadgeTone.success => p.success,
      BadgeTone.warning => p.warning,
      BadgeTone.danger => p.danger,
      BadgeTone.neutral => p.textMuted,
    };
    final fallbackIcon = switch (tone) {
      BadgeTone.danger => Icons.error_outline_rounded,
      BadgeTone.warning => Icons.warning_amber_rounded,
      BadgeTone.success => Icons.check_circle_outline_rounded,
      _ => Icons.info_outline_rounded,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: p.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(icon ?? fallbackIcon, color: color, size: AppSizes.icon),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.text),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
