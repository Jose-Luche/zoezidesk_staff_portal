import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';

/// The 138 px terracotta circle that opens the camera.
class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Scan a member QR code',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: p.halo, shape: BoxShape.circle, boxShadow: AppShadows.lg),
        child: Material(
          color: p.accent,
          shape: const CircleBorder(),
          elevation: 0,
          shadowColor: Organic.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: AppSizes.scanButton - 20,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(AppIcons.scan, size: AppIconSize.scan, color: p.background),
                const SizedBox(height: AppSpace.xs),
                // Cream on terracotta is 3:1: fine at this headline size only.
                Text('Scan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18, color: p.background)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill with an icon and label in the surface fill ("Find", "Register").
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: AppSizes.quickAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: AppIconSize.sm, color: p.accent),
              const SizedBox(width: AppSpace.sm),
              Flexible(child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A round icon button in the surface fill (back, day switcher, close).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.fill,
    this.color,
    this.size = AppSizes.minTouch,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? fill;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fill ?? p.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: AppIconSize.md, color: color ?? p.text, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}

/// A 36 px pill for actions inside cards ("Renew", "Send", "Remind").
class SmallPillButton extends StatelessWidget {
  const SmallPillButton({super.key, required this.label, required this.onPressed, this.filled = true});

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(AppSizes.minTouch, AppSizes.smallButton)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpace.lg)),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelMedium),
    );
    return filled
        ? FilledButton(style: style, onPressed: onPressed, child: Text(label))
        : OutlinedButton(style: style, onPressed: onPressed, child: Text(label));
  }
}
