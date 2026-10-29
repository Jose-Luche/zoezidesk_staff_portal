import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';

/// Designed empty, error and offline states: flush left, a soft icon
/// circle, a Caprasimo title, a short message and one clear action.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  const StateMessage.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : icon = AppIcons.empty;

  const StateMessage.error({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We could not load this. Check your connection and try again.',
    this.actionLabel = 'Try again',
    this.onAction,
  }) : icon = AppIcons.error;

  const StateMessage.offline({
    super.key,
    this.title = 'You are offline',
    this.message = 'This needs an internet connection. Reconnect and try again.',
    this.actionLabel = 'Try again',
    this.onAction,
  }) : icon = AppIcons.offline;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading, vertical: AppSpace.xxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
          child: Icon(icon, size: AppIconSize.md + 2, color: p.accent),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(title, style: text.titleLarge),
        const SizedBox(height: AppSpace.xs),
        Text(message, style: text.bodyMedium?.copyWith(color: p.muted)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpace.xl),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ]),
    );
  }
}
