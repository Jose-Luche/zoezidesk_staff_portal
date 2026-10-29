import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Opens a bottom sheet the Organic way (design.md §3): cream, 34 top
/// radius, a sticky drag handle, at most 92% of the screen, scrolling, and
/// closed by the backdrop or the handle. Desk flows stay on the current
/// screen this way instead of pushing pages.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final duration = AppMotion.of(context, AppMotion.sheet);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
      curve: AppMotion.curve,
      reverseCurve: AppMotion.curve.flipped,
    ),
    builder: builder,
  );
}

/// A sheet's scrolling body: gutters, room for the keyboard and the
/// phone's bottom inset.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + AppSpace.xxl;
    return SingleChildScrollView(
      padding: padding ?? EdgeInsets.fromLTRB(AppGutter.heading, 0, AppGutter.heading, bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A sheet's title and the line under it.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle, this.leading});

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(title, style: text.headlineMedium)),
      if (subtitle != null) ...[
        const SizedBox(height: AppSpace.xs),
        Text(subtitle!, style: text.bodyMedium?.copyWith(color: context.palette.muted)),
      ],
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: leading == null
          ? heading
          : Row(children: [leading!, const SizedBox(width: AppSpace.md), Expanded(child: heading)]),
    );
  }
}
