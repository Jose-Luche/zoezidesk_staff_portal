import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A one-series bar chart of weekly values, oldest week first.
///
/// Thin bars in the accent colour with 4 px rounded tops on a quiet
/// baseline and a 2 px gap between them; a single series, so no legend
/// (the caller titles it). Tapping a bar shows its week and value; the
/// latest week is shown to start with. Screen readers get every value, and
/// [showTable] lists them as text too, so nothing relies on the bars alone.
class WeeklyBars extends StatefulWidget {
  const WeeklyBars({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    required this.semanticTitle,
    this.height = 140,
    this.compact = false,
  });

  /// One value per week; null means nothing that week.
  final List<double?> values;

  /// "Week of" labels, e.g. "3 Oct", same length as [values].
  final List<String> labels;
  final String Function(double value) format;
  final String semanticTitle;
  final double height;

  /// A small sparkline without labels or tapping (for lists).
  final bool compact;

  @override
  State<WeeklyBars> createState() => _WeeklyBarsState();
}

class _WeeklyBarsState extends State<WeeklyBars> {
  late int _selected = _lastWithValue;

  int get _lastWithValue {
    for (var i = widget.values.length - 1; i >= 0; i--) {
      if ((widget.values[i] ?? 0) > 0) return i;
    }
    return widget.values.length - 1;
  }

  @override
  void didUpdateWidget(WeeklyBars old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) _selected = _lastWithValue;
  }

  String _describe(int i) {
    final v = widget.values[i];
    final label = i < widget.labels.length ? widget.labels[i] : '';
    return 'Week of $label: ${v == null || v == 0 ? 'none' : widget.format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final n = widget.values.length;
    if (n == 0) return const SizedBox.shrink();
    final max = widget.values.fold<double>(0, (m, v) => (v ?? 0) > m ? v! : m);

    final chart = SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.compact
              ? null
              : (d) => setState(() => _selected = (d.localPosition.dx / c.maxWidth * n).floor().clamp(0, n - 1)),
          child: CustomPaint(
            size: Size(c.maxWidth, widget.height),
            painter: _BarsPainter(
              values: widget.values,
              max: max,
              bar: p.accentText,
              faded: p.accentText.withValues(alpha: 0.45),
              baseline: p.border,
              selected: widget.compact ? null : _selected,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: '${widget.semanticTitle}. ${[for (var i = 0; i < n; i++) _describe(i)].join('. ')}',
      excludeSemantics: true,
      child: widget.compact
          ? chart
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_describe(_selected), style: text.titleSmall),
                const SizedBox(height: AppSpace.sm),
                chart,
                const SizedBox(height: AppSpace.xs),
                Row(
                  children: [
                    Text(widget.labels.isEmpty ? '' : widget.labels.first, style: text.bodySmall),
                    const Spacer(),
                    Text(widget.labels.isEmpty ? '' : 'This week', style: text.bodySmall),
                  ],
                ),
              ],
            ),
    );
  }
}

/// The values as a plain list, for reading without the chart.
class WeeklyTable extends StatelessWidget {
  const WeeklyTable({super.key, required this.values, required this.labels, required this.format});

  final List<double?> values;
  final List<String> labels;
  final String Function(double value) format;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = values.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(
              children: [
                Expanded(child: Text('Week of ${i < labels.length ? labels[i] : ''}', style: text.bodyMedium)),
                Text((values[i] ?? 0) == 0 ? '—' : format(values[i]!), style: text.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.max,
    required this.bar,
    required this.faded,
    required this.baseline,
    this.selected,
  });

  final List<double?> values;
  final double max;
  final Color bar;
  final Color faded;
  final Color baseline;
  final int? selected;

  static const _gap = 2.0;
  static const _radius = 4.0;
  static const _minVisible = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final slot = size.width / n;
    final width = (slot - _gap).clamp(1.0, 28.0);
    final base = size.height - 1;

    for (var i = 0; i < n; i++) {
      final v = values[i] ?? 0;
      if (v <= 0 || max <= 0) continue;
      final h = (v / max * (base - 4)).clamp(_minVisible, base);
      final left = i * slot + (slot - width) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, base - h, width, h),
        topLeft: const Radius.circular(_radius),
        topRight: const Radius.circular(_radius),
      );
      final colour = selected == null || selected == i ? bar : faded;
      canvas.drawRRect(rect, Paint()..color = colour);
    }

    canvas.drawLine(
      Offset(0, base + 0.5),
      Offset(size.width, base + 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values || old.max != max || old.selected != selected || old.bar != bar;
}
