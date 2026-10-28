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
import '../desk/desk_providers.dart';
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

/// Who is booked into a class: tick off who came, cancel a booking, or book
/// someone in at the desk.
class RosterScreen extends ConsumerWidget {
  const RosterScreen({super.key, required this.classId});

  final int classId;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? done}) async {
    try {
      await action();
      ref
        ..invalidate(rosterProvider(classId))
        ..invalidate(classesProvider);
      if (done != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage(e))));
    }
  }

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final member = await showModalBottomSheet<MemberCard>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FindMemberSheet(),
    );
    if (member == null || !context.mounted) return;
    final api = ref.read(staffApiProvider);
    String? message;
    await _run(context, ref, () async => message = await api.bookClass(classId, member.id));
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message!)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(staffApiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Booked')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _book(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Book someone'),
      ),
      body: AsyncView(
        value: ref.watch(rosterProvider(classId)),
        onRetry: () => ref.invalidate(rosterProvider(classId)),
        data: (bookings) => bookings.isEmpty
            ? const StateMessage.empty(
                title: 'Nobody booked yet',
                message: 'Bookings from the members app show here. Use Book someone for walk-ins.',
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpace.xxxl + AppSpace.lg),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      '${bookings.where((b) => b.status == 'attended').length} of ${bookings.length} came',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final b in bookings)
                    MemberTile(
                      member: b.member,
                      onTap: () => showMemberActions(context, b.member),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Checkbox(
                          value: b.status == 'attended',
                          semanticLabel: '${b.member.name} came',
                          onChanged: (v) => _run(context, ref, () => api.setAttended(classId, b.member.id, attended: v ?? false)),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (_) => _run(context, ref, () => api.cancelBooking(classId, b.member.id),
                              done: "${b.member.name}'s booking cancelled."),
                          itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('Cancel booking'))],
                        ),
                      ]),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Find a member to book into a class (3+ letters of name, phone or number).
class _FindMemberSheet extends ConsumerStatefulWidget {
  const _FindMemberSheet();

  @override
  ConsumerState<_FindMemberSheet> createState() => _FindMemberSheetState();
}

class _FindMemberSheetState extends ConsumerState<_FindMemberSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().length >= 3;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                labelText: 'Book who?',
                hintText: 'Name, phone or member number',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: !searching
                ? const SizedBox.shrink()
                : AsyncView(
                    value: ref.watch(lookupProvider(_query.trim())),
                    onRetry: () => ref.invalidate(lookupProvider(_query.trim())),
                    data: (found) => found.isEmpty
                        ? const StateMessage.empty(title: 'No match', message: 'Try part of the name, or the phone number.')
                        : ListView(children: [
                            for (final m in found) MemberTile(member: m, onTap: () => Navigator.pop(context, m)),
                          ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
