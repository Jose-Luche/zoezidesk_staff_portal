import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/tag.dart';
import '../auth/state/session_controller.dart';
import '../classes/classes_screen.dart';
import '../members/member_providers.dart';
import '../members/member_sheet.dart';
import '../members/note_sheet.dart';
import '../sync/queued_actions_cards.dart';
import 'home_screen.dart';

/// A trainer's day (design.md §5.2): who needs a nudge, their classes, and
/// the notes they wrote last.
class TrainingHome extends ConsumerWidget {
  const TrainingHome({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final dashboard = ref.watch(trainerDashboardProvider);
    final d = dashboard.value;
    final greeting = '${partOfDay(DateTime.now())},\n${firstName(staff.name)}.';

    return RefreshIndicator(
      onRefresh: () {
        if (staff.can('classes.view')) ref.invalidate(todayClassesProvider);
        return ref.refresh(trainerDashboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppGutter.belowNav),
        children: [
          header,
          Greeting(
            title: greeting,
            subtitle: d == null
                ? ' '
                : '${d.clients.length} client${d.clients.length == 1 ? '' : 's'} · ${d.checkInsToday} in today',
          ),
          const QueuedActionsCards(),
          AsyncView(
            value: dashboard,
            onRetry: () => ref.invalidate(trainerDashboardProvider),
            loading: const Padding(padding: EdgeInsets.only(top: AppSpace.xxl), child: SkeletonList.inline()),
            data: (d) => d.clients.isEmpty
                ? const StateMessage.empty(
                    title: 'No clients yet',
                    message: 'A manager assigns members to you on the web staff page.',
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionHeading('Needs attention'),
                    if (d.needsAttention.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading),
                        child: Text('Everyone is training steadily.', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    for (final row in d.needsAttention)
                      MemberRow(
                        member: row.client.card,
                        subtitle: _attention(row.client, inactive: row.inactive),
                        trailing: row.inactive ? const AppTag(label: 'Not training', tone: Tone.danger) : null,
                        onTap: () => showMemberSheet(context, row.client.card),
                      ),
                  ]),
          ),
          if (staff.can('classes.view')) const _YourClasses(),
          if (d != null && d.recentNotes.isNotEmpty) ...[
            const SectionHeading('Your recent notes'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
              child: Column(children: [
                for (final n in d.recentNotes.take(3)) ...[
                  NoteCard(
                    note: n,
                    showMember: true,
                    // Notes carry the member's name: find them among the clients.
                    onTap: switch (d.clients.where((c) => c.card.name == n.member).firstOrNull) {
                      final client? => () => showMemberSheet(context, client.card),
                      null => null,
                    },
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }

  /// "Legs declining · trained 2d ago".
  static String _attention(TrainerClient client, {required bool inactive}) {
    final t = client.training;
    final days = t?.daysSinceWorkout;
    return [
      for (final a in (t?.attention ?? const <({String muscle, String status})>[]).take(2)) '${a.muscle} ${a.status}',
      days == null ? 'no workouts yet' : 'trained ${days == 0 ? 'today' : '${days}d ago'}',
    ].join(' · ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
  }
}

class _YourClasses extends ConsumerWidget {
  const _YourClasses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = (ref.watch(todayClassesProvider).value ?? const <ClassItem>[]).where((c) => c.mine && c.status != 'cancelled');
    if (mine.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading('Your classes today'),
      for (final c in mine)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppGutter.cards, 0, AppGutter.cards, AppSpace.sm),
          child: Consumer(builder: (context, ref, _) {
            final roster = c.canSeeRoster ? ref.watch(rosterProvider(c.id)).value : null;
            final ticked = roster?.where((b) => b.status == 'attended').length;
            return ClassCard(
              item: c,
              sage: true,
              subtitle: '${c.booked}/${c.capacity} booked${ticked == null ? '' : ' · $ticked ticked off'}',
            );
          }),
        ),
    ]);
  }
}
