import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/tag.dart';
import '../payments/payment_actions.dart';
import 'member_photo.dart';
import 'member_providers.dart';
import 'member_sheet.dart';

/// Everything on file for a member: the sheet's essentials, then their
/// details, photo and payments. Opened from the member sheet and from
/// notification links.
class MemberScreen extends ConsumerWidget {
  const MemberScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(memberProfileProvider(memberId));
    return AppPage(
      title: 'Member',
      actions: [
        if (profile.value?.canEdit ?? false)
          CircleIconButton(
            icon: AppIcons.edit,
            tooltip: 'Edit member',
            onPressed: () => context.push(Routes.editMember(memberId)),
          ),
      ],
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(memberProfileProvider(memberId)),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(memberProfileProvider(memberId).future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
            children: [
              // The sheet's body, laid out for a page.
              MemberSheet(key: ValueKey(p.card), member: p.card, inPage: true),
              if (p.canEdit)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => changeMemberPhoto(context, ref, p.card),
                      icon: const Icon(AppIcons.camera, size: AppIconSize.sm),
                      label: Text(p.card.photoUrl == null ? 'Take photo' : 'Change photo'),
                    ),
                  ),
                ),
              _Details(profile: p),
              if (p.payments != null) _Payments(payments: p.payments!, canVoid: p.canVoidPayments),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.profile});

  final MemberProfile profile;

  @override
  Widget build(BuildContext context) {
    final d = profile.details;
    final text = Theme.of(context).textTheme;
    final rows = <(String, String?)>[
      ('Phone', formatLocalPhone(profile.card.phone)),
      ('Email', d['email'] as String?),
      ('Group', d['group'] as String?),
      ('Emergency contact', [d['emergency_contact_name'], d['emergency_contact_phone']].whereType<String>().join(' · ')),
      ('Joined', d['joined_at'] == null ? null : formatShortDate(DateTime.parse(d['joined_at'] as String))),
      ('Last visit', profile.lastVisit == null ? 'Never' : formatDaysAgo(profile.lastVisit!.toLocal(), DateTime.now())),
      ('Notes', d['notes'] as String?),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading('Details'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
        child: SurfaceCard(
          child: Column(children: [
            for (final (label, value) in rows)
              if (value != null && value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 128, child: Text(label, style: text.bodyMedium?.copyWith(color: context.palette.muted))),
                    Expanded(child: Text(value, style: text.bodyMedium)),
                  ]),
                ),
          ]),
        ),
      ),
    ]);
  }
}

class _Payments extends StatelessWidget {
  const _Payments({required this.payments, required this.canVoid});

  final List<PaymentRecord> payments;
  final bool canVoid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeading('Payments'),
      if (payments.isEmpty)
        const StateMessage.empty(title: 'No payments', message: 'Payments for this member show here.'),
      for (final p in payments)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppGutter.rows),
          child: ListTile(
            onTap: () => showPaymentActions(context, p, canVoid: canVoid),
            title: Text('${formatKes(p.amount)} · ${p.plan ?? 'Payment'}'),
            subtitle: Text([
              if (p.paidAt != null) formatShortDate(p.paidAt!),
              p.methodLabel,
              p.recordedBy == null ? 'Paid by member' : 'Taken by ${p.recordedBy}',
            ].join(' · ')),
            trailing: AppTag(
              label: switch (p.status) {
                'completed' => 'Paid',
                'pending' => 'Pending',
                'failed' => 'Failed',
                'voided' => 'Voided',
                _ => p.status,
              },
              tone: switch (p.status) {
                'completed' => Tone.success,
                'pending' => Tone.warning,
                'failed' || 'voided' => Tone.danger,
                _ => Tone.neutral,
              },
            ),
            titleTextStyle: text.titleSmall,
          ),
        ),
    ]);
  }
}
