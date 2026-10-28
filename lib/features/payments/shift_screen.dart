import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift cash-up'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today_rounded),
            label: Text(DateFormat('d MMM').format(query.day)),
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
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(shiftProvider.future),
        child: AsyncView(
          value: shift,
          onRetry: () => ref.invalidate(shiftProvider),
          data: (s) => ListView(
            padding: const EdgeInsets.all(AppSpace.md),
            children: [
              if (s.everyone != null && s.everyone!.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  initialValue: query.staffId,
                  decoration: const InputDecoration(labelText: 'Whose shift'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Mine')),
                    for (final row in s.everyone!)
                      if (row.staffId != staff.id)
                        DropdownMenuItem(value: row.staffId, child: Text('${row.name} · ${formatKes(row.total)}')),
                  ],
                  onChanged: ref.read(shiftQueryProvider.notifier).setStaff,
                ),
                const SizedBox(height: AppSpace.md),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total taken', style: text.labelLarge?.copyWith(color: context.palette.textMuted)),
                      Text(formatKes(s.total), style: text.displaySmall),
                      Text('${s.count} payment${s.count == 1 ? '' : 's'}'),
                      const Divider(height: AppSpace.lg),
                      for (final (key, label) in const [('cash', 'Cash'), ('mpesa', 'M-Pesa'), ('bank', 'Bank')])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                          child: Row(children: [
                            Expanded(child: Text(label)),
                            Text(formatKes(s.byMethod[key] ?? 0), style: text.titleMedium),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
              if (s.voidedCount > 0) ...[
                const SizedBox(height: AppSpace.md),
                InfoBanner(
                  tone: BadgeTone.warning,
                  message: '${s.voidedCount} voided payment${s.voidedCount == 1 ? '' : 's'} '
                      '(${formatKes(s.voidedAmount)}) not counted.',
                ),
              ],
              const SizedBox(height: AppSpace.md),
              if (s.payments.isEmpty)
                const StateMessage.empty(title: 'No payments', message: 'Payments taken on this day show here.')
              else
                for (final p in s.payments) _PaymentTile(payment: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final voided = payment.status == 'voided';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(payment.member ?? 'Member'),
      subtitle: Text([
        if (payment.paidAt != null) DateFormat.Hm().format(payment.paidAt!),
        payment.methodLabel,
        ?payment.plan,
        if (voided) 'Voided: ${payment.voidReason ?? ''}',
      ].join(' · ')),
      trailing: Text(
        formatKes(payment.amount),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              decoration: voided ? TextDecoration.lineThrough : null,
            ),
      ),
    );
  }
}
