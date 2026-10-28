import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/state_message.dart';
import '../desk/member_actions.dart';

final classesDayProvider = NotifierProvider.autoDispose<_Day, DateTime>(_Day.new);

class _Day extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void move(int days) => state = state.add(Duration(days: days));
}

final classesProvider = FutureProvider.autoDispose<List<ClassItem>>(
  (ref) => ref.watch(staffApiProvider).classes(ref.watch(classesDayProvider)),
);

final rosterProvider = FutureProvider.autoDispose.family<List<({MemberCard member, String status})>, int>(
  (ref, id) => ref.watch(staffApiProvider).roster(id),
);

/// The day's classes; instructors see who is booked into theirs.
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(classesDayProvider);
    final classes = ref.watch(classesProvider);
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;

    return Scaffold(
      appBar: AppBar(title: const Text('Classes')),
      body: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => ref.read(classesDayProvider.notifier).move(-1),
          ),
          Expanded(
            child: Text(
              isToday ? 'Today' : DateFormat('EEEE d MMM').format(day),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => ref.read(classesDayProvider.notifier).move(1),
          ),
        ]),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(classesProvider.future),
            child: AsyncView(
              value: classes,
              onRetry: () => ref.invalidate(classesProvider),
              data: (list) => list.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: AppSpace.xxxl),
                      StateMessage.empty(title: 'No classes', message: 'Nothing is scheduled for this day.'),
                    ])
                  : ListView(children: [
                      for (final c in list)
                        ListTile(
                          onTap: c.canSeeRoster ? () => context.push(Routes.roster(c.id)) : null,
                          title: Text(c.name),
                          subtitle: Text('${c.startTime}–${c.endTime}${c.instructor == null ? '' : ' · ${c.instructor}'}'),
                          trailing: Wrap(spacing: AppSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            if (c.status == 'cancelled')
                              const AppBadge(label: 'Cancelled', tone: BadgeTone.danger)
                            else
                              AppBadge(
                                label: '${c.booked}/${c.capacity}',
                                tone: c.booked >= c.capacity ? BadgeTone.warning : BadgeTone.neutral,
                              ),
                            if (c.mine) const AppBadge(label: 'Yours'),
                          ]),
                        ),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class RosterScreen extends ConsumerWidget {
  const RosterScreen({super.key, required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booked')),
      body: AsyncView(
        value: ref.watch(rosterProvider(classId)),
        onRetry: () => ref.invalidate(rosterProvider(classId)),
        data: (bookings) => bookings.isEmpty
            ? const StateMessage.empty(title: 'Nobody booked yet', message: 'Bookings from the members app show here.')
            : ListView(children: [
                for (final b in bookings)
                  MemberTile(
                    member: b.member,
                    trailing: b.status == 'attended' ? const AppBadge(label: 'Attended', tone: BadgeTone.success) : null,
                    onTap: () => showMemberActions(context, b.member),
                  ),
              ]),
      ),
    );
  }
}
