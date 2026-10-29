import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_opener.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../members/member_providers.dart';

final enquiriesProvider = FutureProvider.autoDispose<List<Enquiry>>((ref) => ref.watch(staffApiProvider).enquiries());

/// Open walk-in enquiries, follow-ups due first: call, WhatsApp, log how it
/// went, or register them as a member.
class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enquiries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newEnquiry),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New enquiry'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(enquiriesProvider.future),
        child: AsyncView(
          value: ref.watch(enquiriesProvider),
          onRetry: () => ref.invalidate(enquiriesProvider),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: AppSpace.xxxl),
                  StateMessage.empty(
                    title: 'No open enquiries',
                    message: 'Record walk-ins with New enquiry, so nobody who asked about the gym is forgotten.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpace.xxxl + AppSpace.lg),
                  children: [for (final e in list) _EnquiryTile(enquiry: e)],
                ),
        ),
      ),
    );
  }
}

class _EnquiryTile extends ConsumerWidget {
  const _EnquiryTile({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = enquiry;
    final open = ref.watch(urlOpenerProvider);
    final gym = ref.watch(staffProvider).gymName;
    final phone = normalizeKenyanPhone(e.phone);
    final due = e.nextFollowUpAt;
    final initials = e.name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

    return ListTile(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _FollowUpSheet(enquiry: e),
      ),
      leading: MemberAvatar(initials: initials),
      title: Text(e.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text([?e.interestedIn, 'came ${formatRelative(e.createdAt, DateTime.now())}'].join(' · ')),
          AppBadge(label: e.stageLabel, tone: e.stage == 'interested' ? BadgeTone.success : BadgeTone.neutral),
          if (due != null)
            AppBadge(
              label: e.overdue ? 'Call overdue' : 'Call ${formatDate(due)}',
              tone: e.overdue ? BadgeTone.danger : BadgeTone.warning,
            ),
        ]),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Call ${e.name}',
          icon: const Icon(Icons.call_rounded),
          onPressed: () => open(Uri(scheme: 'tel', path: '+$phone')),
        ),
        IconButton(
          tooltip: 'WhatsApp ${e.name}',
          icon: const Icon(Icons.chat_rounded),
          onPressed: () => open(Uri.https('wa.me', '/$phone', {
            'text': 'Hi ${e.name.split(' ').first}, thanks for visiting $gym! '
                '${e.interestedIn == null ? '' : 'You asked about our ${e.interestedIn} membership. '}'
                'Is there anything we can help with to get you started?',
          })),
        ),
      ]),
    );
  }
}

/// After calling: how it went and when to call again, or register them.
class _FollowUpSheet extends ConsumerStatefulWidget {
  const _FollowUpSheet({required this.enquiry});

  final Enquiry enquiry;

  @override
  ConsumerState<_FollowUpSheet> createState() => _FollowUpSheetState();
}

class _FollowUpSheetState extends ConsumerState<_FollowUpSheet> {
  static const _outcomes = {'contacted': 'Spoke to them', 'interested': 'Interested', 'lost': 'Not joining'};

  final _note = TextEditingController();
  String _outcome = 'contacted';
  DateTime? _nextOn = DateTime.now().add(const Duration(days: 3));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(staffApiProvider).followUpEnquiry(
            widget.enquiry.id,
            outcome: _outcome,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            nextOn: _outcome == 'lost' ? null : _nextOn,
            lostReason: _outcome == 'lost' && _note.text.trim().isNotEmpty ? _note.text.trim() : null,
          );
      ref.invalidate(enquiriesProvider);
      if (mounted) Navigator.pop(context);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      final member = await ref.read(staffApiProvider).convertEnquiry(widget.enquiry.id);
      ref
        ..invalidate(enquiriesProvider)
        ..invalidate(membersPageProvider);
      if (!mounted) return;
      final staff = ref.read(staffProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member.name} is now member ${member.memberNumber}.')));
      if (staff.can('payments.record')) context.push(Routes.pay(member.id));
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enquiry;
    final canRegister = ref.watch(staffProvider).can('members.create');

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(e.name, style: Theme.of(context).textTheme.titleLarge),
        Text([formatLocalPhone(e.phone), ?e.interestedIn].join(' · ')),
        if (e.notes != null) Text(e.notes!, style: TextStyle(color: context.palette.textMuted)),
        const SizedBox(height: AppSpace.md),
        if (canRegister) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _register,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Register as member'),
          ),
          const Divider(height: AppSpace.xl),
        ],
        Text('How did the follow-up go?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: AppSpace.sm, children: [
          for (final MapEntry(:key, :value) in _outcomes.entries)
            ChoiceChip(label: Text(value), selected: _outcome == key, onSelected: (_) => setState(() => _outcome = key)),
        ]),
        const SizedBox(height: AppSpace.sm),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: _outcome == 'lost' ? 'Why not? (optional)' : 'Note (optional)'),
        ),
        if (_outcome != 'lost')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(_nextOn == null ? 'No next call' : 'Call again ${formatDate(_nextOn!)}'),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _nextOn ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _nextOn = picked);
            },
          ),
        if (_error != null) FormErrorText(_error!),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save follow-up')),
      ]),
    );
  }
}
