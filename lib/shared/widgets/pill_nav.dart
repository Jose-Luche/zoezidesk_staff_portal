import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// The floating bottom nav: a dark pill 16 px from the sides and 24 from
/// the bottom, three labelled items, the selected one filled with accent.
class PillNav extends StatelessWidget {
  const PillNav({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.labelMedium;
    final duration = AppMotion.of(context, AppMotion.fast);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: p.text,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.lg,
          ),
          child: Row(children: [
            for (final (i, label) in labels.indexed)
              Expanded(
                child: Semantics(
                  selected: i == selected,
                  button: true,
                  label: '$label tab',
                  excludeSemantics: true,
                  child: Material(
                    color: Organic.transparent,
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelected(i),
                      child: AnimatedContainer(
                        duration: duration,
                        height: AppSizes.navItem,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == selected ? p.accent : Organic.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        // On the accent fill the label is dark: cream would
                        // be 3:1 at this size.
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style?.copyWith(color: i == selected ? p.onAccent : p.background),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
