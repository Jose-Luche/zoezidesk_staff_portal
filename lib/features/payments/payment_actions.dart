import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_opener.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../desk/desk_providers.dart';

/// A payment's receipt and, for owners and managers, voiding it.
Future<void> showPaymentActions(BuildContext context, PaymentRecord payment, {bool canVoid = false}) =>
    showAppSheet<void>(context, builder: (_) => _PaymentActions(payment: payment, canVoid: canVoid));

/// Opens the receipt PDF in the phone's viewer.
Future<void> openReceipt(BuildContext context, WidgetRef ref, int paymentId) async {
  try {
    final url = await ref.read(staffApiProvider).receiptLink(paymentId);
    if (!await ref.read(urlOpenerProvider)(Uri.parse(url)) && context.mounted) {
      _say(context, 'No app on this phone can open the receipt.');
    }
  } catch (e) {
    if (context.mounted) _say(context, failureMessage(e));
  }
}

/// Sends the member a WhatsApp message with a link to their receipt.
Future<void> sendReceipt(BuildContext context, WidgetRef ref, PaymentRecord payment) async {
  final phone = payment.memberPhone;
  if (phone == null) return _say(context, 'This member has no phone number.');
  try {
    final url = await ref.read(staffApiProvider).receiptLink(payment.id);
    final gym = ref.read(staffProvider).gymName;
    final firstName = (payment.member ?? '').split(' ').first;
    final text = 'Hi $firstName, thank you for your payment of ${formatKes(payment.amount)} at $gym. '
        'Your receipt: $url';
    final whatsapp = Uri.https('wa.me', '/${normalizeKenyanPhone(phone)}', {'text': text});
    if (!await ref.read(urlOpenerProvider)(whatsapp) && context.mounted) {
      _say(context, 'WhatsApp is not on this phone.');
    }
  } catch (e) {
    if (context.mounted) _say(context, failureMessage(e));
  }
}

void _say(BuildContext context, String message) => showToast(context, message);

class _PaymentActions extends ConsumerStatefulWidget {
  const _PaymentActions({required this.payment, required this.canVoid});

  final PaymentRecord payment;
  final bool canVoid;

  @override
  ConsumerState<_PaymentActions> createState() => _PaymentActionsState();
}

class _PaymentActionsState extends ConsumerState<_PaymentActions> {
  late PaymentRecord _payment = widget.payment;

  Future<void> _void() async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _VoidDialog());
    if (reason == null || !mounted) return;
    try {
      final voided = await ref.read(staffApiProvider).voidPayment(_payment.id, reason);
      memberDataChanged(ref);
      setState(() => _payment = voided);
      if (mounted) _say(context, 'Payment voided.');
    } catch (e) {
      if (mounted) _say(context, failureMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _payment;
    final completed = p.status == 'completed';

    return SheetBody(children: [
      SheetTitle(
        formatKes(p.amount),
        subtitle: [
          ?p.member,
          ?p.plan,
          p.methodLabel,
          if (p.paidAt != null) formatShortDate(p.paidAt!),
          if (p.reference != null) 'Ref ${p.reference}',
          p.recordedBy == null ? 'Paid by the member' : 'Taken by ${p.recordedBy}',
        ].join(' · '),
      ),
      if (p.status == 'voided') ...[
        InfoCard(title: 'Voided', message: p.voidReason ?? 'No reason given.', tone: Tone.danger, icon: AppIcons.voided),
        const SizedBox(height: AppSpace.lg),
      ],
      if (completed) ...[
        FilledButton(onPressed: () => openReceipt(context, ref, p.id), child: const Text('Open receipt')),
        const SizedBox(height: AppSpace.sm),
        OutlinedButton.icon(
          onPressed: p.memberPhone == null ? null : () => sendReceipt(context, ref, p),
          icon: const Icon(AppIcons.whatsapp, size: AppIconSize.sm),
          label: const Text('Send receipt on WhatsApp'),
        ),
      ],
      if (completed && widget.canVoid) ...[
        const SizedBox(height: AppSpace.sm),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: context.palette.danger.on),
            onPressed: _void,
            icon: const Icon(AppIcons.voided, size: AppIconSize.sm),
            label: const Text('Void payment'),
          ),
        ),
      ],
    ]);
  }
}

/// Asks why the payment is being voided. Pops with the reason.
class _VoidDialog extends StatefulWidget {
  const _VoidDialog();

  @override
  State<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<_VoidDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (_reason.text.trim().length < 5) return setState(() => _error = 'Say why, in a few words.');
    Navigator.pop(context, _reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: const Text('Void this payment?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('It stops counting in revenue and cash-ups, and the membership it paid for is cancelled. '
            'Any money to give back is refunded outside ZoeziDesk.'),
        const SizedBox(height: AppSpace.lg),
        AppField(
          label: 'Reason',
          controller: _reason,
          autofocus: true,
          maxLength: 255,
          hint: 'e.g. Recorded twice by mistake',
          error: _error,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep it')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.danger.on, foregroundColor: p.danger.fill),
          onPressed: _submit,
          child: const Text('Void payment'),
        ),
      ],
    );
  }
}
