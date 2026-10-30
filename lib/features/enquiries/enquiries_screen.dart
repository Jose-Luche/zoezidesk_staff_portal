import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_opener.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/repositories/read_cache.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../members/member_providers.dart';
import '../payments/pay_sheet.dart';

final enquiriesProvider = cachedRead((_) => StaffReads.enquiries);

/// Open walk-in enquiries, follow-ups due first: call, WhatsApp, log how it
/// went, or register them as a member.
class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Enquiries',
      actions: [
        TextButton.icon(
          onPressed: () => context.push(Routes.newEnquiry),
          icon: const Icon(AppIcons.add, size: AppIconSize.sm),
          label: const Text('New'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(enquiriesProvider.future),
        child: AsyncView(
          value: ref.watch(enquiriesProvider),
          onRetry: () => ref.invalidate(enquiriesProvider),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  StateMessage.empty(
                    title: 'No open enquiries',
                    message: 'Record walk-ins with New, so nobody who asked about the gym is forgotten.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.xxxl),
                  children: [for (final e in list) _EnquiryRow(enquiry: e)],
                ),
        ),
      ),
    );
  }
}

class _EnquiryRow extends ConsumerWidget {
  const _EnquiryRow({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = enquiry;
    final open = ref.watch(urlOpenerProvider);
    final gym = ref.watch(staffProvider).gymName;
    final phone = normalizeKenyanPhone(e.phone);
    final due = e.nextFollowUpAt;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGutter.rows),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: () => showAppSheet<void>(context, builder: (_) => _FollowUpSheet(enquiry: e)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            MemberAvatar(initials: initialsOf(e.name), seed: e.id),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: text.titleSmall),
                Text([?e.interestedIn, 'came ${formatDaysAgo(e.createdAt, DateTime.now())}'].join(' · '), style: text.bodySmall),
                const SizedBox(height: AppSpace.xs),
                Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                  AppTag(label: e.stageLabel, tone: e.stage == 'interested' ? Tone.success : Tone.neutral),
                  if (due != null)
                    AppTag(
                      label: e.overdue ? 'Call overdue' : 'Call ${formatShortDate(due)}',
                      tone: e.overdue ? Tone.danger : Tone.warning,
                    ),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'Call ${e.name}',
              icon: const Icon(AppIcons.call, size: AppIconSize.md),
              onPressed: () => open(Uri(scheme: 'tel', path: '+$phone')),
            ),
            IconButton(
              tooltip: 'WhatsApp ${e.name}',
              icon: const Icon(AppIcons.whatsapp, size: AppIconSize.md),
              onPressed: () => open(Uri.https('wa.me', '/$phone', {
                'text': 'Hi ${firstName(e.name)}, thanks for visiting $gym! '
                    '${e.interestedIn == null ? '' : 'You asked about our ${e.interestedIn} membership. '}'
                    'Is there anything we can help with to get you started?',
              })),
            ),
          ]),
        ),
      ),
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
      if (!mounted) return;
      showToast(context, 'Follow-up saved');
      Navigator.pop(context);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      final MemberCard member = await ref.read(staffApiProvider).convertEnquiry(widget.enquiry.id);
      ref
        ..invalidate(enquiriesProvider)
        ..invalidate(membersPageProvider);
      if (!mounted) return;
      final canPay = ref.read(staffProvider).can('payments.record');
      final navigator = Navigator.of(context);
      final outer = navigator.context;
      showToast(context, '${firstName(member.name)} is now member #${member.memberNumber}');
      navigator.pop();
      if (canPay && outer.mounted) await showPaySheet(outer, memberId: member.id);
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
    final text = Theme.of(context).textTheme;

    return SheetBody(children: [
      SheetTitle(e.name, subtitle: [formatLocalPhone(e.phone), ?e.interestedIn].join(' · ')),
      if (e.notes != null) ...[
        Text(e.notes!, style: text.bodyMedium?.copyWith(color: context.palette.muted)),
        const SizedBox(height: AppSpace.lg),
      ],
      if (canRegister) ...[
        FilledButton(onPressed: _busy ? null : _register, child: const Text('Register as member')),
        const SizedBox(height: AppSpace.xxl),
      ],
      Text('How did the follow-up go?', style: text.titleMedium),
      const SizedBox(height: AppSpace.md),
      Wrap(spacing: AppSpace.sm, children: [
        for (final MapEntry(:key, :value) in _outcomes.entries)
          PillChip(label: value, selected: _outcome == key, onTap: () => setState(() => _outcome = key)),
      ]),
      const SizedBox(height: AppSpace.lg),
      AppField(label: _outcome == 'lost' ? 'Why not? (optional)' : 'Note (optional)', controller: _note),
      if (_outcome != 'lost') ...[
        const SizedBox(height: AppSpace.md),
        QuickDateButton(
          label: _nextOn == null ? 'No next call' : 'Call again ${formatDayDate(_nextOn!)}',
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
      ],
      if (_error != null) ...[const SizedBox(height: AppSpace.lg), FormErrorText(_error!)],
      const SizedBox(height: AppSpace.xl),
      OutlinedButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save follow-up')),
    ]);
  }
}

/// "Call them back Thu 31 Oct" in a surface pill.
class QuickDateButton extends StatelessWidget {
  const QuickDateButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.palette.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: AppSizes.input,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Icon(AppIcons.calendar, size: AppIconSize.md, color: context.palette.accent),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
                Text('Change', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.palette.accentText)),
              ]),
            ),
          ),
        ),
      );
}
