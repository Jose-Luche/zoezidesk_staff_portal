import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

enum BadgeTone { highlight, success, warning, danger, neutral }

/// Small status label, e.g. "Active", "Pending", "Expires in 3 days".
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.highlight,
    this.icon,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;

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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpace.md, color: color),
            const SizedBox(width: AppSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
