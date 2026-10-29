import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../classes/classes_screen.dart';
import '../desk/desk_providers.dart';
import '../desk/offline_desk.dart';
import '../members/member_sheet.dart';
import '../members/register_sheet.dart';
import '../payments/pay_sheet.dart';
import 'home_screen.dart';

/// The front desk (design.md §5.1): scan first, then whatever needs a
/// person now, then who came in last.
class DeskHome extends ConsumerWidget {
  const DeskHome({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final today = ref.watch(todayCheckInsProvider);
    final checkIns = today.value?.checkIns ?? const <TodayCheckIn>[];
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () {
        if (staff.can('classes.view')) ref.invalidate(todayClassesProvider);
        return ref.refresh(todayCheckInsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppGutter.belowNav),
        children: [
          header,
          Greeting(
            title: '${partOfDay(DateTime.now())},\n${firstName(staff.name)}.',
            subtitle: today.hasValue ? _soFar(today.requireValue.count, checkIns) : ' ',
          ),
          const SizedBox(height: AppSpace.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
            child: Row(children: [
              ScanButton(onPressed: () => context.push(Routes.scan)),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  QuickAction(icon: AppIcons.search, label: 'Find', onPressed: () => _find(context, ref)),
                  if (staff.can('members.create')) ...[
                    const SizedBox(height: AppSpace.md),
                    QuickAction(
                      icon: AppIcons.register,
                      label: 'Register',
                      onPressed: () => showRegisterSheet(context, ref),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          const SectionHeading('Needs you now'),
          const _NeedsYou(),
          SectionHeading(
            'Latest in',
            action: checkIns.length > 3
                ? TextButton(onPressed: () => _allToday(context), child: Text('See all ${checkIns.length}'))
                : null,
          ),
          AsyncView(
            value: today,
            onRetry: () => ref.invalidate(todayCheckInsProvider),
            loading: const SkeletonList.inline(),
            data: (data) => data.checkIns.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading),
                    child: Text('Nobody in yet. Scanned members show here.', style: text.bodyMedium),
                  )
                : Column(children: [
                    for (final c in data.checkIns.take(3))
                      MemberRow(
                        member: c.member,
                        inAt: c.at,
                        inBy: c.method,
                        onTap: () => showMemberSheet(context, c.member),
                      ),
                  ]),
          ),
        ],
      ),
    );
  }

  /// "14 in so far · busiest at 07:00".
  static String _soFar(int count, List<TodayCheckIn> checkIns) {
    if (count == 0) return 'Nobody in yet';
    final byHour = <int, int>{};
    for (final c in checkIns) {
      byHour[c.at.hour] = (byHour[c.at.hour] ?? 0) + 1;
    }
    final busiest = byHour.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return '$count in so far · busiest at ${busiest.toString().padLeft(2, '0')}:00';
  }

  /// The Members tab when this person has it; otherwise a quick lookup
  /// (trainers at the desk can serve anyone, not browse everyone).
  Future<void> _find(BuildContext context, WidgetRef ref) async {
    if (tabsFor(ref.read(staffProvider)).any((t) => t.path == Routes.members)) {
      context.go(Routes.members);
      return;
    }
    final member = await showAppSheet<MemberCard>(context, builder: (_) => const FindMemberSheet(title: 'Find a member'));
    if (member != null && context.mounted) await showMemberSheet(context, member);
  }

  void _allToday(BuildContext context) => showAppSheet<void>(
        context,
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            final data = ref.watch(todayCheckInsProvider).value;
            return SheetBody(padding: const EdgeInsets.only(bottom: AppSpace.xxl), children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading),
                child: SheetTitle('In today', subtitle: data == null ? null : '${data.count} so far'),
              ),
              for (final c in data?.checkIns ?? const <TodayCheckIn>[])
                MemberRow(
                  member: c.member,
                  inAt: c.at,
                  inBy: c.method,
                  subtitle: '${MemberRow.defaultSubtitle(c.member, inAt: c.at, inBy: c.method)}${c.by == null ? '' : ' · ${c.by}'}',
                  onTap: () => showMemberSheet(context, c.member),
                ),
            ]);
          },
        ),
      );
}

/// Action cards, most urgent first; "All clear" when there are none.
class _NeedsYou extends ConsumerStatefulWidget {
  const _NeedsYou();

  @override
  ConsumerState<_NeedsYou> createState() => _NeedsYouState();
}

class _NeedsYouState extends ConsumerState<_NeedsYou> {
  bool _sending = false;

  Future<void> _send() async {
    final desk = ref.read(offlineDeskProvider.notifier);
    final before = ref.read(offlineDeskProvider).pending.length;
    setState(() => _sending = true);
    await desk.send();
    if (!mounted) return;
    setState(() => _sending = false);
    final sent = before - ref.read(offlineDeskProvider).pending.length;
    showToast(
      context,
      sent == 0 ? 'Still offline. They go when the connection is back.' : '$sent check-in${sent == 1 ? '' : 's'} sent',
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final checkIns = ref.watch(todayCheckInsProvider).value?.checkIns ?? const <TodayCheckIn>[];
    final offline = ref.exists(offlineDeskProvider) ? ref.watch(offlineDeskProvider) : null;
    final classes = staff.can('classes.view') ? ref.watch(todayClassesProvider).value ?? const <ClassItem>[] : const <ClassItem>[];

    // In today, but their membership has ended or ends this week.
    final seen = <int>{};
    final renewals = [
      for (final c in checkIns)
        if (needsRenewal(c.member) && seen.add(c.member.id)) c.member,
    ];
    final full = classes.where((c) => c.status != 'cancelled' && c.booked >= c.capacity).toList();

    final cards = <Widget>[
      for (final m in renewals)
        ActionCard(
          tone: Tone.warning,
          badge: Text(m.initials),
          title: '${firstName(m.name)} is in',
          subtitle: m.membership == null
              ? 'No plan yet'
              : '${m.membership!.plan ?? 'Membership'} ${m.membership!.current ? 'ends' : 'ended'} ${formatShortDate(m.membership!.expiresAt)}',
          actionLabel: staff.can('payments.record') ? 'Renew' : null,
          onAction: () => showPaySheet(context, memberId: m.id),
          onTap: () => showMemberSheet(context, m),
        ),
      if (offline != null && offline.pending.isNotEmpty)
        ActionCard(
          tone: Tone.warning,
          badge: Text('${offline.pending.length}'),
          title: '${offline.pending.length} check-in${offline.pending.length == 1 ? '' : 's'} waiting',
          subtitle: 'Saved offline at ${formatTime(offline.pending.last.at.toLocal())}',
          actionLabel: _sending ? 'Sending…' : 'Send',
          onAction: _sending ? null : _send,
        ),
      if (offline != null && offline.refused.isNotEmpty)
        ActionCard(
          tone: Tone.danger,
          badge: const Icon(AppIcons.refused),
          title: 'Refused when sent',
          subtitle: offline.refused
              .map((r) => '${r.name} at ${formatTime(r.at.toLocal())}: ${r.message}')
              .join('\n'),
          actionLabel: 'Dismiss',
          onAction: () => ref.read(offlineDeskProvider.notifier).dismissRefused(),
        ),
      for (final c in full)
        ActionCard(
          tone: Tone.neutral,
          badge: Text(c.startTime.length >= 5 ? c.startTime.substring(0, 5) : c.startTime,
              style: const TextStyle(fontSize: 11)),
          title: '${c.name}${c.instructor == null ? '' : ' with ${c.instructor}'} · full',
          subtitle: '${c.booked}/${c.capacity} booked',
          onTap: c.canSeeRoster ? () => showRosterSheet(context, c) : null,
        ),
    ];

    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
        child: SurfaceCard(
          color: context.palette.success.fill,
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(children: [
            Icon(AppIcons.success, color: context.palette.success.on),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text('All clear. Nothing waiting on you.',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.palette.success.on)),
            ),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
      child: Column(children: [
        for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(height: AppSpace.sm), card],
      ]),
    );
  }
}
