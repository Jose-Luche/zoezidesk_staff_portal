import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/tag.dart';
import '../auth/state/session_controller.dart';
import 'payment_actions.dart';
import 'payment_providers.dart';

/// End-of-shift cash-up. Owners and managers can open anyone's.
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final query = ref.watch(shiftQueryProvider);
    final shift = ref.watch(shiftProvider);
    final text = Theme.of(context).textTheme;
    final p = context.palette;

    return AppPage(
      title: 'My shift',
      actions: [
        TextButton.icon(
          icon: const Icon(AppIcons.calendar, size: AppIconSize.sm),
          label: Text(formatShortDate(query.day)),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: query.day,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) ref.read(shiftQueryProvider.notifier).setDay(picked);
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(shiftProvider.future),
        child: AsyncView(
          value: shift,
          onRetry: () => ref.invalidate(shiftProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(AppGutter.cards, AppSpace.sm, AppGutter.cards, AppSpace.xxxl),
            children: [
              if (s.everyone != null && s.everyone!.isNotEmpty) ...[
                ChipRow(padding: EdgeInsets.zero, children: [
                  PillChip(label: 'Mine', selected: query.staffId == null, onTap: () => ref.read(shiftQueryProvider.notifier).setStaff(null)),
                  for (final row in s.everyone!)
                    if (row.staffId != staff.id)
                      PillChip(
                        label: '${firstName(row.name)} · ${formatKes(row.total)}',
                        selected: query.staffId == row.staffId,
                        onTap: () => ref.read(shiftQueryProvider.notifier).setStaff(row.staffId),
                      ),
                ]),
                const SizedBox(height: AppSpace.md),
              ],
              SurfaceCard(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total taken', style: text.bodySmall),
                  Text(formatKes(s.total), style: text.displaySmall),
                  Text('${s.count} payment${s.count == 1 ? '' : 's'}', style: text.bodySmall),
                  const SizedBox(height: AppSpace.lg),
                  for (final (key, label, color) in [
                    ('cash', 'Cash', p.accent),
                    ('mpesa', 'M-Pesa', p.sage),
                    ('bank', 'Bank', p.methodBank),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                        const SizedBox(width: AppSpace.md),
                        Expanded(child: Text(label, style: text.bodyMedium)),
                        Text(formatKes(s.byMethod[key] ?? 0), style: text.titleSmall),
                      ]),
                    ),
                ]),
              ),
              if (s.voidedCount > 0) ...[
                const SizedBox(height: AppSpace.md),
                InfoCard(
                  tone: Tone.warning,
                  icon: AppIcons.voided,
                  message: '${s.voidedCount} voided payment${s.voidedCount == 1 ? '' : 's'} '
                      '(${formatKes(s.voidedAmount)}) not counted.',
                ),
              ],
              const SectionHeading('Payments', padding: EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xxl, 0, AppSpace.sm)),
              if (s.payments.isEmpty)
                const StateMessage.empty(title: 'No payments', message: 'Payments taken on this day show here.')
              else
                for (final payment in s.payments) _PaymentTile(payment: payment, canVoid: staff.can('payments.void')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.canVoid});

  final PaymentRecord payment;
  final bool canVoid;

  @override
  Widget build(BuildContext context) {
    final voided = payment.status == 'voided';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      onTap: () => showPaymentActions(context, payment, canVoid: canVoid),
      title: Text(payment.member ?? 'Member'),
      subtitle: Text([
        if (payment.paidAt != null) formatTime(payment.paidAt!),
        payment.methodLabel,
        ?payment.plan,
        if (voided) 'Voided: ${payment.voidReason ?? ''}',
      ].join(' · ')),
      trailing: Text(
        formatKes(payment.amount),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(decoration: voided ? TextDecoration.lineThrough : null),
      ),
    );
  }
}
