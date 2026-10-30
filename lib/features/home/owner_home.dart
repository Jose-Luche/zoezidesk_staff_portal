import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/work.dart';
import '../../data/repositories/read_cache.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/day_bars.dart';
import '../../shared/widgets/skeleton.dart';
import '../auth/state/session_controller.dart';
import '../desk/follow_ups_screen.dart';
import '../sync/queued_actions_cards.dart';
import 'home_screen.dart';

final todayReportProvider = cachedRead((_) => StaffReads.todayReport);

final reportPeriodProvider = NotifierProvider.autoDispose<_Period, String>(_Period.new);

class _Period extends Notifier<String> {
  @override
  String build() => 'this_month';

  void set(String period) => state = period;
}

/// A period's figures: this_week, this_month or last_month.
final periodReportProvider = cachedReadFamily((_, String period) => StaffReads.periodReport(period));

/// Owners and managers (design.md §5.3): today at a glance, the week's
/// check-ins, then a period's revenue. Tables and exports stay on the web.
class OwnerHome extends ConsumerWidget {
  const OwnerHome({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final today = ref.watch(todayReportProvider);
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(periodReportProvider);
        return ref.refresh(todayReportProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppGutter.belowNav),
        children: [
          header,
          Greeting(
            title: staff.gymName.isEmpty ? 'Today' : staff.gymName,
            large: false,
            subtitle: '${DateFormat('EEEE d MMM').format(now)}'
                '${today.hasValue ? ' · ${today.requireValue.kpi('checkins_today')} in so far' : ''}',
          ),
          const QueuedActionsCards(),
          const SizedBox(height: AppSpace.xxl),
          AsyncView(
            value: today,
            onRetry: () => ref.invalidate(todayReportProvider),
            loading: const SkeletonList.inline(),
            data: (t) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
                child: _Tiles(report: t),
              ),
              const SectionHeading('Check-ins, last 7 days'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
                child: DayBars(
                  values: _lastWeek(t.attendanceSeries),
                  labels: [
                    for (var i = 6; i >= 0; i--)
                      i == 0 ? 'Today' : DateFormat.E().format(now.subtract(Duration(days: i))),
                  ],
                  semanticTitle: 'Check-ins per day, last 7 days',
                ),
              ),
            ]),
          ),
          const SectionHeading('Revenue'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppGutter.cards),
            child: _PeriodSection(),
          ),
        ],
      ),
    );
  }

  /// The last seven days of a daily series, padded at the start if shorter.
  static List<int> _lastWeek(List<double> series) => [
        for (var i = series.length - 7; i < series.length; i++) i < 0 ? 0 : series[i].round(),
      ];
}

class _Tiles extends ConsumerWidget {
  const _Tiles({required this.report});

  final TodayReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = report;
    // Joined this month comes with the month's report.
    final joined = ref.watch(periodReportProvider('this_month')).value?.memberships['new_this_month'];
    final tiles = [
      StatTile(value: formatKes(t.kpi('revenue_today')), caption: 'Revenue today'),
      StatTile(value: '${t.kpi('checkins_today')}', caption: 'Check-ins today'),
      StatTile(value: '${t.kpi('active_members')}', caption: 'Active members'),
      StatTile(value: joined == null ? '—' : '$joined', caption: 'Joined this month'),
      StatTile(value: '${t.kpi('expiring_7d')}', caption: 'Expiring in 7 days', onTap: () => showFollowUpsSheet(context)),
      StatTile(value: '${t.kpi('lapsed_30d')}', caption: 'Lapsed (30 days)', onTap: () => showFollowUpsSheet(context)),
    ];
    return Column(children: [
      for (var i = 0; i < tiles.length; i += 2) ...[
        if (i > 0) const SizedBox(height: AppSpace.sm),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: tiles[i + 1]),
          ]),
        ),
      ],
    ]);
  }
}

class _PeriodSection extends ConsumerWidget {
  const _PeriodSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(periodReportProvider(period));
    final p = context.palette;
    final text = Theme.of(context).textTheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PillSegmented<String>(
        accent: true,
        options: const [('this_week', 'Week'), ('this_month', 'Month'), ('last_month', 'Last month')],
        selected: period,
        onChanged: ref.read(reportPeriodProvider.notifier).set,
      ),
      const SizedBox(height: AppSpace.md),
      AsyncView(
        value: report,
        onRetry: () => ref.invalidate(periodReportProvider(period)),
        loading: const SurfaceCard(child: SkeletonBox(width: 160, height: 28)),
        data: (r) {
          final byMethod = (r.revenue['by_method'] as List).cast<Map<String, dynamic>>();
          final change = r.revenue['change_pct'] as num?;
          return SurfaceCard(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatKes(r.revenue['total'] as num), style: text.displaySmall),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${r.revenue['count']} payments'
                '${change == null ? '' : ' · ${change >= 0 ? '+' : ''}$change% vs the period before'}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpace.lg),
              for (final m in byMethod)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (m['method']) { 'mpesa' => p.sage, 'cash' => p.accent, _ => p.methodBank },
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(
                        switch (m['method']) { 'mpesa' => 'M-Pesa', 'cash' => 'Cash', 'bank' => 'Bank', final o => '$o' },
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(formatKes(m['total'] as num), style: text.titleSmall),
                  ]),
                ),
              const SizedBox(height: AppSpace.md),
              Text(
                '${r.attendance['total']} check-ins by ${r.attendance['unique_members']} members · '
                '${r.memberships['active_members']} of ${r.memberships['total_members']} active',
                style: text.bodySmall,
              ),
            ]),
          );
        },
      ),
    ]);
  }
}
