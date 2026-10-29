import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import 'buttons.dart';
import 'tag.dart';

/// A section title, flush left, with an optional ghost action on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.padding});

  final String title;
  final Widget? action;

  /// Defaults to the heading gutter, with room above.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.xxl, AppGutter.cards, AppSpace.sm),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge))),
          ?action,
        ]),
      );
}

/// A flat surface card (radius 26, no shadow).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.color,
    this.radius = AppRadius.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return Material(
      color: color ?? context.palette.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, customBorder: shape, child: Padding(padding: padding, child: child)),
    );
  }
}

/// "Needs you now": a tinted card with a badge circle, two lines and an
/// optional small action.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.tone,
    required this.badge,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  final Tone tone;

  /// Initials, a count or a time, drawn in the 42 px circle.
  final Widget badge;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = tone.tint(p);
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      color: t.fill,
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: p.background.withValues(alpha: 0.7), shape: BoxShape.circle),
          child: DefaultTextStyle.merge(
            style: text.labelMedium?.copyWith(color: t.on, fontWeight: FontWeight.w700),
            child: IconTheme.merge(data: IconThemeData(color: t.on, size: AppIconSize.md), child: badge),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text.titleSmall?.copyWith(color: t.on)),
            if (subtitle != null) Text(subtitle!, style: text.bodySmall?.copyWith(color: t.on)),
          ]),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: AppSpace.sm),
          SmallPillButton(label: actionLabel!, onPressed: onAction),
        ],
      ]),
    );
  }
}

/// A figure and its caption. Tappable tiles take the warning tint and say
/// where they lead ("See who →").
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.caption, this.onTap, this.linkLabel = 'See who'});

  final String value;
  final String caption;
  final VoidCallback? onTap;
  final String linkLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final t = onTap == null ? null : p.warning;
    return Semantics(
      button: onTap != null,
      label: '$caption: $value',
      excludeSemantics: true,
      child: SurfaceCard(
        color: t?.fill,
        radius: AppRadius.tile,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.headlineMedium?.copyWith(color: t?.on)),
          ),
          const SizedBox(height: 2),
          Text(caption, style: text.bodySmall?.copyWith(fontSize: 12, color: t?.on ?? p.muted)),
          if (onTap != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text('$linkLabel →', style: text.labelMedium?.copyWith(color: t!.on)),
          ],
        ]),
      ),
    );
  }
}

/// An inline notice in its meaning's tint, with an icon so meaning never
/// rests on color alone. Used for form errors and status lines.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.message, this.tone = Tone.neutral, this.icon, this.title, this.action});

  final String message;
  final String? title;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = tone.tint(context.palette);
    final text = Theme.of(context).textTheme;
    final fallback = switch (tone) {
      Tone.danger || Tone.warning => AppIcons.error,
      Tone.success => AppIcons.success,
      Tone.neutral => AppIcons.info,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: SurfaceCard(
        color: t.fill,
        radius: AppRadius.tile,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.md, AppSpace.md),
        child: Row(children: [
          Icon(icon ?? fallback, size: AppIconSize.md, color: t.on),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null) Text(title!, style: text.titleSmall?.copyWith(color: t.on)),
              Text(message, style: text.bodyMedium?.copyWith(color: t.on)),
            ]),
          ),
          if (action != null) ...[const SizedBox(width: AppSpace.sm), action!],
        ]),
      ),
    );
  }
}

/// Inline error under a form, in the danger tint.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => InfoCard(message: message, tone: Tone.danger);
}

/// The one soft sage circle bleeding off the top-right of a screen.
class CornerDecoration extends StatelessWidget {
  const CornerDecoration({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        top: -90,
        right: -80,
        child: ExcludeSemantics(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(color: context.palette.decoration, shape: BoxShape.circle),
          ),
        ),
      );
}
