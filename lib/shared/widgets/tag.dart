import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// What a tag, card or banner means: its tint (design.md §2.1).
enum Tone { success, warning, danger, neutral }

extension ToneTint on Tone {
  Tint tint(AppPalette p, {bool tag = false}) => switch (this) {
        Tone.success => tag ? p.successTag : p.success,
        Tone.warning => p.warning,
        Tone.danger => p.danger,
        Tone.neutral => p.neutral,
      };
}

/// Small status pill: a plan name, "Ends 28 Nov", "Expired", "Yours".
class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = tone.tint(context.palette, tag: true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: t.on),
          const SizedBox(width: AppSpace.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.on, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
