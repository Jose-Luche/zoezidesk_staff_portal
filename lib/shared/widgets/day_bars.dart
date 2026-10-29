import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// One value per day (check-ins, last 7 days): pill bars in sage with the
/// last one (today) in accent, the value above and the day below, in a
/// surface card. Screen readers get every value.
class DayBars extends StatelessWidget {
  const DayBars({super.key, required this.values, required this.labels, required this.semanticTitle, this.height = 110});

  final List<int> values;
  final List<String> labels;
  final String semanticTitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final max = values.fold<int>(0, (m, v) => v > m ? v : m);
    return Semantics(
      label: '$semanticTitle. ${[for (var i = 0; i < values.length; i++) '${labels[i]}: ${values[i]}'].join('. ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.md),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${values[i]}', style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpace.xs),
                Container(
                  width: 22,
                  height: max == 0 ? 6 : 6 + (height - 6) * values[i] / max,
                  decoration: BoxDecoration(
                    color: i == values.length - 1 ? p.accent : p.chartBar,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(labels[i], style: text.labelSmall?.copyWith(color: p.muted)),
              ]),
            ),
        ]),
      ),
    );
  }
}
