import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/weekly_bars.dart';
import '../auth/state/session_controller.dart';

final todayReportProvider = FutureProvider.autoDispose<TodayReport>(
  (ref) => ref.watch(staffApiProvider).todayReport(),
);

final reportPeriodProvider = NotifierProvider.autoDispose<_Period, String>(
  _Period.new,
);

class _Period extends Notifier<String> {
  @override
  String build() => 'this_month';

  void set(String period) => state = period;
}

final periodReportProvider = FutureProvider.autoDispose<PeriodReport>(
  (ref) =>
      ref.watch(staffApiProvider).periodReport(ref.watch(reportPeriodProvider)),
);

/// Owners and managers: today at a glance, then a period's totals. The same
/// figures as the web reports; tables and exports stay on the web.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final today = ref.watch(todayReportProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(staff.gymName.isEmpty ? 'Today' : staff.gymName),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(periodReportProvider);
          return ref.refresh(todayReportProvider.future);
        },
        child: AsyncView(
          value: today,
          onRetry: () => ref.invalidate(todayReportProvider),
          data: (t) {
            final change = t.kpis['revenue_change_pct'] as num?;
            return ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpace.sm,
                  crossAxisSpacing: AppSpace.sm,
                  childAspectRatio: 1.6,
                  children: [
                    _Kpi('Revenue today', formatKes(t.kpi('revenue_today'))),
                    _Kpi('Check-ins today', '${t.kpi('checkins_today')}'),
                    _Kpi(
                      'This month',
                      formatKes(t.kpi('revenue_mtd')),
                      note: change == null
                          ? null
                          : '${change >= 0 ? '+' : ''}$change% vs last month',
                    ),
                    _Kpi('Active members', '${t.kpi('active_members')}'),
                    _Kpi(
                      'Expiring in 7 days',
                      '${t.kpi('expiring_7d')}',
                      onTap: () => context.push(Routes.followUps),
                    ),
                    _Kpi(
                      'Lapsed (30 days)',
                      '${t.kpi('lapsed_30d')}',
                      onTap: () => context.push(Routes.followUps),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Check-ins, last 7 days', style: text.titleMedium),
                const SizedBox(height: AppSpace.sm),
                WeeklyBars(
                  values: _lastWeek(t.attendanceSeries),
                  labels: [
                    for (var i = 6; i >= 0; i--)
                      DateFormat.E().format(
                        DateTime.now().subtract(Duration(days: i)),
                      ),
                  ],
                  format: (v) => '${v.round()}',
                  semanticTitle: 'Check-ins per day, last 7 days',
                  periodPrefix: '',
                  lastLabel: 'Today',
                ),
                const SizedBox(height: AppSpace.lg),
                const _PeriodSection(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The last seven days of a daily series, padded at the start if shorter.
List<double?> _lastWeek(List<double> series) => [
  for (var i = series.length - 7; i < series.length; i++)
    i < 0 ? null : series[i],
];

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.note, this.onTap});

  final String label;
  final String value;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
              FittedBox(child: Text(value, style: text.headlineMedium)),
              if (note != null) Text(note!, style: text.bodySmall),
              if (onTap != null)
                Text(
                  'See who',
                  style: text.labelMedium?.copyWith(
                    color: context.palette.accentText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSection extends ConsumerWidget {
  const _PeriodSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final report = ref.watch(periodReportProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'this_week', label: Text('Week')),
            ButtonSegment(value: 'this_month', label: Text('Month')),
            ButtonSegment(value: 'last_month', label: Text('Last month')),
          ],
          selected: {period},
          onSelectionChanged: (s) =>
              ref.read(reportPeriodProvider.notifier).set(s.first),
        ),
        const SizedBox(height: AppSpace.md),
        AsyncView(
          value: report,
          onRetry: () => ref.invalidate(periodReportProvider),
          loading: const LinearProgressIndicator(),
          data: (r) {
            final byMethod = (r.revenue['by_method'] as List)
                .cast<Map<String, dynamic>>();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue',
                      style: text.labelLarge?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                    Text(
                      formatKes(r.revenue['total'] as num),
                      style: text.displaySmall,
                    ),
                    Text(
                      '${r.revenue['count']} payments · ${r.revenue['change_pct']}% vs the period before',
                    ),
                    const Divider(height: AppSpace.lg),
                    for (final m in byMethod)
                      Row(
                        children: [
                          Expanded(
                            child: Text(switch (m['method']) {
                              'mpesa' => 'M-Pesa',
                              'cash' => 'Cash',
                              'bank' => 'Bank',
                              final o => '$o',
                            }),
                          ),
                          Text(formatKes(m['total'] as num)),
                        ],
                      ),
                    const Divider(height: AppSpace.lg),
                    Text(
                      '${r.attendance['total']} check-ins by ${r.attendance['unique_members']} members',
                    ),
                    Text(
                      '${r.memberships['active_members']} active of ${r.memberships['total_members']} members',
                    ),
                    Text(
                      '${r.memberships['new_this_month']} joined this month',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
