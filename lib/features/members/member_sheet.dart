import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../desk/desk_providers.dart';
import '../payments/pay_sheet.dart';
import 'member_providers.dart';
import 'note_sheet.dart';

/// A member at the counter: who they are, where their membership stands,
/// and the two things the desk does (take a payment, check in), without
/// leaving the screen. Training and notes for those allowed to see them.
Future<void> showMemberSheet(BuildContext context, MemberCard member) =>
    showAppSheet<void>(context, builder: (_) => MemberSheet(member: member));

class MemberSheet extends ConsumerStatefulWidget {
  const MemberSheet({super.key, required this.member, this.inPage = false});

  final MemberCard member;

  /// On the member page, which already has the details.
  final bool inPage;

  @override
  ConsumerState<MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<MemberSheet> {
  late MemberCard _card = widget.member;
  DateTime? _checkedInAt;
  bool _busy = false;
  String? _why;

  DateTime? _inAt() {
    if (_checkedInAt != null) return _checkedInAt;
    final today = ref.watch(todayCheckInsProvider).value?.checkIns ?? const [];
    return today.where((c) => c.member.id == _card.id).firstOrNull?.at;
  }

  Future<void> _checkIn() async {
    if (!_card.isCurrent) {
      return setState(() => _why = _card.status == 'active'
          ? 'Membership not active. Take a payment first.'
          : '${firstName(_card.name)} is ${_card.status}. A manager can change that on the web.');
    }
    setState(() {
      _busy = true;
      _why = null;
    });
    try {
      final result = await ref.read(staffApiProvider).checkIn(memberId: _card.id);
      memberDataChanged(ref);
      if (!mounted) return;
      if (result.success) {
        setState(() => _checkedInAt = DateTime.now());
        showToast(context, result.duplicate ? '${firstName(_card.name)} is already in' : '${firstName(_card.name)} is checked in');
      } else {
        setState(() => _why = result.message);
      }
    } catch (e) {
      if (mounted) setState(() => _why = failureMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final outcome = await showPaySheet(context, memberId: _card.id);
    if (outcome == null || !mounted) return;
    try {
      final card = await ref.read(staffApiProvider).card(_card.id);
      if (mounted) setState(() => _card = card);
    } catch (_) {
      // The old card is still right about who they are.
    }
    if (outcome.checkedIn && mounted) setState(() => _checkedInAt ??= DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final card = _card;
    final inAt = _inAt();
    final mayOpenProfile = staff.can('members.view') || staff.can('members.view_assigned');
    final profile = mayOpenProfile ? ref.watch(memberProfileProvider(card.id)) : null;
    final details = profile?.value;
    final m = card.membership;

    return SheetBody(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: MemberAvatar(initials: card.initials, photoUrl: card.photoUrl, seed: card.id, size: 74),
      ),
      const SizedBox(height: AppSpace.lg),
      Text(card.name, style: text.headlineMedium),
      const SizedBox(height: AppSpace.xs),
      Text(MemberRow.defaultSubtitle(card), style: text.bodyMedium?.copyWith(color: p.muted)),
      const SizedBox(height: AppSpace.md),
      Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
        MembershipTag(member: card),
        if (inAt != null) AppTag(label: 'In at ${formatTime(inAt)}', tone: Tone.success),
      ]),
      const SizedBox(height: AppSpace.xl),
      Row(children: [
        if (staff.can('payments.record'))
          Expanded(
            child: FilledButton(onPressed: _pay, child: Text(card.isCurrent ? 'Renew' : 'Take payment')),
          ),
        if (staff.can('payments.record') && staff.can('checkin.scan')) const SizedBox(width: AppSpace.sm),
        if (staff.can('checkin.scan'))
          Expanded(
            child: Opacity(
              // Dimmed but still tappable, so it can say why.
              opacity: card.isCurrent || inAt != null ? 1 : 0.45,
              child: OutlinedButton(
                onPressed: inAt != null || _busy ? null : _checkIn,
                child: Text(inAt != null ? 'In at ${formatTime(inAt)}' : (_busy ? 'Checking in…' : 'Check in')),
              ),
            ),
          ),
      ]),
      if (_why != null) ...[
        const SizedBox(height: AppSpace.md),
        InfoCard(message: _why!, tone: Tone.warning),
      ],
      const SizedBox(height: AppSpace.lg),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (details != null) ...[
          Expanded(child: StatTile(value: '${details.visitsThisMonth}', caption: 'visits this month')),
          const SizedBox(width: AppSpace.sm),
        ],
        Expanded(
          child: StatTile(
            value: m == null ? '—' : formatShortDate(m.expiresAt),
            caption: m == null ? 'no plan yet' : (m.current ? 'active until' : 'ended'),
          ),
        ),
        if (_joined(details) case final joined?) ...[
          const SizedBox(width: AppSpace.sm),
          Expanded(child: StatTile(value: joined, caption: 'joined')),
        ],
        ]),
      ),
      if (details != null && !staff.sharedDevice && details.canViewTraining) _Training(memberId: card.id),
      if (details != null && !staff.sharedDevice && details.canManageNotes) _Notes(member: card),
      if (staff.sharedDevice || (details != null && !details.canViewTraining)) ...[
        const SizedBox(height: AppSpace.xl),
        Text(
          "Training and notes are shown to the member's trainer, managers and owners.",
          style: text.bodySmall,
        ),
      ],
      if (details != null && !staff.sharedDevice && !widget.inPage) ...[
        const SizedBox(height: AppSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.member(card.id));
            },
            icon: const Icon(AppIcons.go, size: AppIconSize.sm),
            label: const Text('Details, payments and photo'),
          ),
        ),
      ],
    ]);
  }

  /// "Mar 2024", from the profile.
  static String? _joined(MemberProfile? profile) {
    final at = profile?.details['joined_at'] as String?;
    if (at == null) return null;
    final d = DateTime.parse(at);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _Training extends ConsumerWidget {
  const _Training({required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeading('Training', padding: const EdgeInsets.only(top: AppSpace.xxl, bottom: AppSpace.sm)),
        AsyncView(
          value: ref.watch(memberTrainingProvider(memberId)),
          onRetry: () => ref.invalidate(memberTrainingProvider(memberId)),
          loading: const SkeletonBox(width: 200),
          data: (t) => t == null
              ? Text('No workouts logged yet.', style: Theme.of(context).textTheme.bodyMedium)
              : TrainingFacts(training: t),
        ),
      ]);
}

/// Last workout, sessions in four weeks, and muscles that need attention.
class TrainingFacts extends StatelessWidget {
  const TrainingFacts({super.key, required this.training});

  final TrainingSummary training;

  @override
  Widget build(BuildContext context) {
    final t = training;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        t.lastWorkout == null
            ? 'No workouts logged yet'
            : 'Last workout ${formatDaysAgo(t.lastWorkout!, DateTime.now())} · ${t.sessions28d} in 4 weeks',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (t.attention.isNotEmpty) ...[
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
          for (final a in t.attention)
            AppTag(label: '${a.muscle} ${a.status}', tone: a.status == 'declining' ? Tone.danger : Tone.warning),
        ]),
      ],
    ]);
  }
}

class _Notes extends ConsumerWidget {
  const _Notes({required this.member});

  final MemberCard member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(memberNotesProvider(member.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(
        'Trainer notes',
        padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.xs),
        action: TextButton.icon(
          onPressed: () => showNoteSheet(context, ref, member),
          icon: const Icon(AppIcons.add, size: AppIconSize.sm),
          label: const Text('Add'),
        ),
      ),
      AsyncView(
        value: notes,
        onRetry: () => ref.invalidate(memberNotesProvider(member.id)),
        loading: const SkeletonBox(width: 220),
        data: (list) => list.isEmpty
            ? Text('No notes yet.', style: Theme.of(context).textTheme.bodyMedium)
            : Column(children: [
                for (final n in list) ...[NoteCard(note: n, memberId: member.id), const SizedBox(height: AppSpace.sm)],
              ]),
      ),
    ]);
  }
}
