import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../desk/member_actions.dart';
import 'member_providers.dart';

/// A member's profile. Training and notes only for staff who may see them
/// (the member's trainer, owners and managers on their own phone).
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(memberProfileProvider(memberId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member'),
        actions: [
          if (profile.value?.canEdit ?? false)
            IconButton(
              tooltip: 'Edit member',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => context.push(Routes.editMember(memberId)),
            ),
        ],
      ),
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(memberProfileProvider(memberId)),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(memberProfileProvider(memberId).future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
            children: [
              MemberTile(member: p.card),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Wrap(spacing: AppSpace.sm, children: [
                  if (p.canTakePayment)
                    FilledButton.icon(
                      onPressed: () => context.push(Routes.pay(p.card.id)),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Take payment'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => showMemberActions(context, p.card),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Check in'),
                  ),
                ]),
              ),
              _Details(profile: p),
              if (p.canViewTraining) _Training(memberId: memberId),
              if (p.canManageNotes) _Notes(memberId: memberId),
              if (p.payments != null) _Payments(payments: p.payments!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            ?action,
          ]),
          const SizedBox(height: AppSpace.sm),
          ...children,
        ]),
      );
}

class _Details extends StatelessWidget {
  const _Details({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final d = profile.details;
    final rows = <(String, String?)>[
      ('Phone', formatLocalPhone(profile.card.phone)),
      ('Email', d['email'] as String?),
      ('Group', d['group'] as String?),
      ('Emergency contact', [d['emergency_contact_name'], d['emergency_contact_phone']].whereType<String>().join(' · ')),
      ('Joined', d['joined_at'] == null ? null : formatDate(DateTime.parse(d['joined_at'] as String))),
      ('Visits this month', '${profile.visitsThisMonth}'),
      ('Last visit', profile.lastVisit == null ? 'Never' : formatRelative(profile.lastVisit!.toLocal(), DateTime.now())),
      ('Notes', d['notes'] as String?),
    ];
    return _Section(title: 'Details', children: [
      for (final (label, value) in rows)
        if (value != null && value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 140,
                child: Text(label, style: TextStyle(color: context.palette.textMuted)),
              ),
              Expanded(child: Text(value)),
            ]),
          ),
    ]);
  }
}

class _Training extends ConsumerWidget {
  const _Training({required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(title: 'Training', children: [
      AsyncView(
        value: ref.watch(memberTrainingProvider(memberId)),
        onRetry: () => ref.invalidate(memberTrainingProvider(memberId)),
        loading: const SkeletonList.inline(itemCount: 1),
        data: (t) => t == null ? const Text('No workouts logged yet.') : TrainingFacts(training: t),
      ),
    ]);
  }
}

/// Last workout, sessions in four weeks, and muscles that need attention.
class TrainingFacts extends StatelessWidget {
  const TrainingFacts({super.key, required this.training});

  final TrainingSummary training;

  @override
  Widget build(BuildContext context) {
    final t = training;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.lastWorkout == null
          ? 'No workouts logged yet'
          : 'Last workout ${formatRelative(t.lastWorkout!, DateTime.now())} · ${t.sessions28d} in 4 weeks'),
      if (t.attention.isNotEmpty) ...[
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
          for (final a in t.attention)
            AppBadge(
              label: '${a.muscle} ${a.status}',
              tone: a.status == 'declining' ? BadgeTone.danger : BadgeTone.warning,
            ),
        ]),
      ],
    ]);
  }
}

class _Notes extends ConsumerWidget {
  const _Notes({required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Trainer notes',
      action: TextButton.icon(
        onPressed: () => _addNote(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      children: [
        AsyncView(
          value: ref.watch(memberNotesProvider(memberId)),
          onRetry: () => ref.invalidate(memberNotesProvider(memberId)),
          loading: const SkeletonList.inline(itemCount: 2),
          data: (notes) => notes.isEmpty
              ? const Text('No notes yet.')
              : Column(children: [
                  for (final n in notes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(n.note),
                      subtitle: Text('${n.typeLabel} · ${formatDate(n.sessionDate)}${n.trainer == null ? '' : ' · ${n.trainer}'}'),
                      trailing: n.mine
                          ? IconButton(
                              tooltip: 'Delete note',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                await ref.read(staffApiProvider).deleteNote(n.id);
                                ref.invalidate(memberNotesProvider(memberId));
                              },
                            )
                          : null,
                    ),
                ]),
        ),
      ],
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NoteSheet(memberId: memberId),
    );
    if (saved == true) ref.invalidate(memberNotesProvider(memberId));
  }
}

/// Quick note after a session: type chips, today's date, the text.
class NoteSheet extends ConsumerStatefulWidget {
  const NoteSheet({super.key, required this.memberId});

  final int memberId;

  @override
  ConsumerState<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<NoteSheet> {
  static const _types = {'session': 'Session', 'progress': 'Progress', 'health': 'Health', 'general': 'General'};

  final _note = TextEditingController();
  String _type = 'session';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_note.text.trim().length < 5) return setState(() => _error = 'Write at least a few words.');
    setState(() => _busy = true);
    try {
      await ref.read(staffApiProvider).addNote(widget.memberId, type: _type, note: _note.text.trim(), sessionDate: DateTime.now());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = failureMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, MediaQuery.viewInsetsOf(context).bottom + AppSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('New note', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.sm, children: [
          for (final MapEntry(:key, :value) in _types.entries)
            ChoiceChip(label: Text(value), selected: _type == key, onSelected: (_) => setState(() => _type = key)),
        ]),
        if (_type == 'health')
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text('Health notes are only seen by trainers, managers and owners.',
                style: TextStyle(color: context.palette.textMuted)),
          ),
        const SizedBox(height: AppSpace.md),
        TextField(
          controller: _note,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(labelText: 'Note', errorText: _error),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save note')),
      ]),
    );
  }
}

class _Payments extends StatelessWidget {
  const _Payments({required this.payments});

  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    return _Section(title: 'Payments', children: [
      if (payments.isEmpty) const StateMessage.empty(title: 'No payments', message: 'Payments for this member show here.'),
      for (final p in payments)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${formatKes(p.amount)} · ${p.plan ?? 'Payment'}'),
          subtitle: Text([
            if (p.paidAt != null) formatDate(p.paidAt!),
            p.methodLabel,
            p.recordedBy == null ? 'Paid by member' : 'Taken by ${p.recordedBy}',
          ].join(' · ')),
          trailing: AppBadge(
            label: switch (p.status) {
              'completed' => 'Paid',
              'pending' => 'Pending',
              'failed' => 'Failed',
              'voided' => 'Voided',
              _ => p.status,
            },
            tone: switch (p.status) {
              'completed' => BadgeTone.success,
              'pending' => BadgeTone.warning,
              'failed' => BadgeTone.danger,
              _ => BadgeTone.neutral,
            },
          ),
        ),
    ]);
  }
}
