import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';
import '../../data/repositories/read_cache.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../desk/desk_providers.dart';
import '../members/member_sheet.dart';

final classesDayProvider = NotifierProvider.autoDispose<_Day, DateTime>(_Day.new);

class _Day extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void move(int days) => state = state.add(Duration(days: days));
}

final classesProvider = cachedRead((ref) => StaffReads.classes(ref.watch(classesDayProvider)));

/// Today's classes whatever day the Classes tab shows (for Home).
final todayClassesProvider = cachedRead((_) {
  final now = DateTime.now();
  return StaffReads.classes(DateTime(now.year, now.month, now.day));
});

final rosterProvider = cachedReadFamily((_, int id) => StaffReads.roster(id));

bool _isFull(ClassItem c) => c.status != 'cancelled' && c.booked >= c.capacity;

/// The day's classes; instructors see who is booked into theirs.
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(classesDayProvider);
    final classes = ref.watch(classesProvider);
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(classesProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppGutter.belowNav),
            children: [
              const TabHeadline('Classes'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
                child: Row(children: [
                  CircleIconButton(
                    icon: AppIcons.back,
                    tooltip: 'Previous day',
                    onPressed: () => ref.read(classesDayProvider.notifier).move(-1),
                  ),
                  Expanded(
                    child: Text(
                      isToday ? 'Today' : formatDayDate(day),
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                  ),
                  CircleIconButton(
                    icon: AppIcons.forward,
                    tooltip: 'Next day',
                    onPressed: () => ref.read(classesDayProvider.notifier).move(1),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpace.lg),
              AsyncView(
                value: classes,
                onRetry: () => ref.invalidate(classesProvider),
                loading: const SkeletonList.inline(),
                data: (list) => list.isEmpty
                    ? const StateMessage.empty(title: 'No classes', message: 'Nothing is scheduled for this day.')
                    : Column(children: [
                        for (final c in list)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppGutter.cards, 0, AppGutter.cards, AppSpace.sm),
                            child: ClassCard(item: c),
                          ),
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A class: start time in a circle, name, "{time} · {coach}" and how full.
/// Opens the roster when this staff member may see it.
class ClassCard extends StatelessWidget {
  const ClassCard({super.key, required this.item, this.sage = false, this.subtitle});

  final ClassItem item;

  /// The sage card of "Your classes today".
  final bool sage;

  /// Replaces "{time} · {coach}".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final c = item;
    final on = sage ? p.success.on : p.text;
    return SurfaceCard(
      color: sage ? p.success.fill : null,
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: c.canSeeRoster ? () => showRosterSheet(context, c) : null,
      child: Row(children: [
        TimeCircle(time: c.startTime),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: text.titleSmall?.copyWith(color: on)),
            Text(
              subtitle ?? '${c.startTime}–${c.endTime}${c.instructor == null ? '' : ' · ${c.instructor}'}',
              style: text.bodySmall?.copyWith(color: sage ? on : null),
            ),
          ]),
        ),
        const SizedBox(width: AppSpace.sm),
        if (sage && c.canSeeRoster)
          SmallPillButton(label: 'Roster', onPressed: () => showRosterSheet(context, c))
        else
          Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, alignment: WrapAlignment.end, children: [
          if (c.status == 'cancelled')
            const AppTag(label: 'Cancelled', tone: Tone.danger)
          else
            AppTag(label: '${c.booked}/${c.capacity}', tone: _isFull(c) ? Tone.warning : Tone.neutral),
          if (c.mine && !sage) const AppTag(label: 'Yours', tone: Tone.success),
        ]),
      ]),
    );
  }
}

/// The start time in a 46 px circle.
class TimeCircle extends StatelessWidget {
  const TimeCircle({super.key, required this.time});

  /// "07:30" or "07:30:00".
  final String time;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hhmm = time.length >= 5 ? time.substring(0, 5) : time;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.background, shape: BoxShape.circle),
      child: Text(hhmm, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

Future<void> showRosterSheet(BuildContext context, ClassItem item) =>
    showAppSheet<void>(context, builder: (_) => SheetBody(children: [RosterView(classId: item.id, item: item)]));

/// The roster as a page, for links from notifications.
class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key, required this.classId});

  final int classId;

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Roster',
        body: SheetBody(children: [RosterView(classId: classId)]),
      );
}

/// Who is booked into a class: tick off who came, cancel a booking, or book
/// someone in at the desk.
class RosterView extends ConsumerWidget {
  const RosterView({super.key, required this.classId, this.item});

  final int classId;

  /// The class, when known, for the title line.
  final ClassItem? item;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? done}) async {
    try {
      await action();
      ref
        ..invalidate(rosterProvider(classId))
        ..invalidate(classesProvider)
        ..invalidate(todayClassesProvider);
      if (done != null && context.mounted) showToast(context, done);
    } catch (e) {
      if (context.mounted) showToast(context, failureMessage(e));
    }
  }

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final member = await showAppSheet<MemberCard>(context, builder: (_) => const FindMemberSheet(title: 'Book who?'));
    if (member == null || !context.mounted) return;
    final api = ref.read(staffApiProvider);
    String? message;
    await _run(context, ref, () async => message = await api.bookClass(classId, member.id));
    if (message != null && context.mounted) showToast(context, message!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(staffApiProvider);
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final c = item;
    final inToday = {
      for (final ci in ref.watch(todayCheckInsProvider).value?.checkIns ?? const <TodayCheckIn>[]) ci.member.id: ci.at,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c != null)
        SheetTitle(
          c.name,
          subtitle: [
            '${c.startTime}–${c.endTime}',
            ?c.instructor,
            '${c.booked}/${c.capacity} booked',
          ].join(' · '),
        ),
      AsyncView(
        value: ref.watch(rosterProvider(classId)),
        onRetry: () => ref.invalidate(rosterProvider(classId)),
        loading: const SkeletonList.inline(),
        data: (bookings) {
          final came = bookings.where((b) => b.status == 'attended').length;
          final more = (c?.booked ?? 0) - bookings.length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (bookings.isEmpty)
              const StateMessage.empty(
                title: 'Nobody booked yet',
                message: 'Bookings from the members app show here. Use Book someone for walk-ins.',
              )
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
                  decoration: BoxDecoration(color: p.success.fill, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('$came of ${bookings.length} ticked off', style: text.labelMedium?.copyWith(color: p.success.on)),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              for (final b in bookings)
                _RosterRow(
                  member: b.member,
                  came: b.status == 'attended',
                  inSince: inToday[b.member.id],
                  onTick: (v) => _run(context, ref, () => api.setAttended(classId, b.member.id, attended: v)),
                  onCancel: () => _run(context, ref, () => api.cancelBooking(classId, b.member.id),
                      done: "${firstName(b.member.name)}'s booking cancelled"),
                ),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm, left: AppSpace.sm),
                  child: Text('+ $more more booked from the members app', style: text.bodySmall),
                ),
            ],
            const SizedBox(height: AppSpace.xl),
            OutlinedButton.icon(
              onPressed: () => _book(context, ref),
              icon: const Icon(AppIcons.register, size: AppIconSize.sm),
              label: const Text('Book someone'),
            ),
          ]);
        },
      ),
    ]);
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.member,
    required this.came,
    required this.inSince,
    required this.onTick,
    required this.onCancel,
  });

  final MemberCard member;
  final bool came;
  final DateTime? inSince;
  final ValueChanged<bool> onTick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.tile),
      onTap: () => showMemberSheet(context, member),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          MemberAvatar(initials: member.initials, photoUrl: member.photoUrl, seed: member.id),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                came
                    ? 'Came'
                    : inSince != null
                        ? 'In the building since ${formatTime(inSince!)}'
                        : 'Booked',
                style: text.bodySmall,
              ),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(AppIcons.more, size: AppIconSize.md),
            onSelected: (_) => onCancel(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'cancel', child: Text('Cancel booking'))],
          ),
          CheckToggle(value: came, onChanged: onTick, semanticLabel: '${member.name} came'),
        ]),
      ),
    );
  }
}

/// Find any member (3+ letters of name, phone or number) and pop with them.
class FindMemberSheet extends ConsumerStatefulWidget {
  const FindMemberSheet({super.key, required this.title});

  final String title;

  @override
  ConsumerState<FindMemberSheet> createState() => _FindMemberSheetState();
}

class _FindMemberSheetState extends ConsumerState<FindMemberSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().length >= 3;
    return SheetBody(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading),
          child: SheetTitle(widget.title),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
          child: AppField(
            label: 'Search',
            autofocus: true,
            hint: 'Name, phone or member number',
            prefixIcon: AppIcons.search,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (searching)
          AsyncView(
            value: ref.watch(lookupProvider(_query.trim())),
            onRetry: () => ref.invalidate(lookupProvider(_query.trim())),
            loading: const SkeletonList.inline(),
            data: (found) => found.isEmpty
                ? const StateMessage.empty(title: 'No match', message: 'Try part of the name, or the phone number.')
                : Column(children: [
                    for (final m in found) MemberRow(member: m, onTap: () => Navigator.pop(context, m)),
                  ]),
          ),
      ],
    );
  }
}
