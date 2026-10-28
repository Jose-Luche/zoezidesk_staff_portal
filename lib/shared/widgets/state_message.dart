import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Designed empty, error and offline states: an icon, a short message and
/// one clear action.
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
  }) : icon = Icons.inbox_rounded;

  const StateMessage.error({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We could not load this. Check your connection and try again.',
    this.actionLabel = 'Try again',
    this.onAction,
  }) : icon = Icons.error_outline_rounded;

  const StateMessage.offline({
    super.key,
    this.title = 'You are offline',
    this.message = 'This needs an internet connection. Reconnect and try again.',
    this.actionLabel = 'Try again',
    this.onAction,
  }) : icon = Icons.cloud_off_rounded;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpace.xxl, color: palette.textMuted),
            const SizedBox(height: AppSpace.md),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
