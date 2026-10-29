import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../desk/desk_providers.dart';
import 'payment_actions.dart';
import 'payment_providers.dart';

/// Take a payment for a member: pick the plan, then cash, bank or M-Pesa.
class PayScreen extends ConsumerWidget {
  const PayScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(paySetupProvider(memberId));
    return Scaffold(
      appBar: AppBar(title: const Text('Take payment')),
      body: AsyncView(
        value: setup,
        onRetry: () => ref.invalidate(paySetupProvider(memberId)),
        data: (s) => _PayForm(member: s.member, plans: s.plans),
      ),
    );
  }
}

class _PayForm extends ConsumerStatefulWidget {
  const _PayForm({required this.member, required this.plans});

  final MemberCard member;
  final Plans plans;

  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final _phone = TextEditingController(text: formatLocalPhone(widget.member.phone));
  Plan? _plan;
  String _method = 'cash';
  bool _notify = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _choose(Plan plan) => setState(() {
        _plan = plan;
        _amount.text = '${plan.price}';
        _error = null;
      });

  Future<void> _submit() async {
    final plan = _plan;
    if (plan == null) return setState(() => _error = 'Choose a plan.');
    final api = ref.read(staffApiProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_method == 'mpesa') {
        if (!isMpesaPhone(_phone.text)) throw const ValidationFailure('Enter a Safaricom number, like 0712 345 678.');
        final payment = await api.requestMpesa(
          memberId: widget.member.id,
          planId: plan.id,
          phone: normalizeKenyanPhone(_phone.text),
        );
        if (mounted) context.pushReplacement(Routes.payment(payment.id));
        return;
      }
      final amount = int.tryParse(_amount.text.trim());
      if (amount == null || amount < 1) throw const ValidationFailure('Enter the amount received.');
      final payment = await api.payCash(
        memberId: widget.member.id,
        planId: plan.id,
        amount: amount,
        method: _method,
        reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notify: _notify,
      );
      memberDataChanged(ref);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.check_circle_rounded, color: context.palette.success, size: AppSpace.xxl),
          title: Text('${formatKes(payment.amount)} received'),
          content: Text('${widget.member.name}\'s ${plan.name} membership is active.'),
          actions: [
            TextButton(
              onPressed: () => sendReceipt(context, ref, payment),
              child: const Text('Send receipt'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
      if (mounted) context.pop();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plans = widget.plans;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.md),
      children: [
        MemberTile(member: widget.member),
        const SizedBox(height: AppSpace.md),
        Text('Plan', style: text.titleMedium),
        const SizedBox(height: AppSpace.sm),
        RadioGroup<int>(
          groupValue: _plan?.id,
          onChanged: (id) => _choose(plans.plans.firstWhere((p) => p.id == id)),
          child: Column(children: [
            for (final plan in plans.plans)
              RadioListTile<int>(
                value: plan.id,
                title: Text(plan.name),
                subtitle: Text([plan.durationLabel, if (plan.category != 'standard') plan.category].join(' · ')),
                secondary: Text(formatKes(plan.price), style: text.titleSmall),
              ),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        Text('Paid by', style: text.titleMedium),
        const SizedBox(height: AppSpace.sm),
        SegmentedButton<String>(
          segments: [
            const ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments_rounded)),
            const ButtonSegment(value: 'bank', label: Text('Bank'), icon: Icon(Icons.account_balance_rounded)),
            if (plans.mpesaEnabled)
              const ButtonSegment(value: 'mpesa', label: Text('M-Pesa'), icon: Icon(Icons.phone_android_rounded)),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        const SizedBox(height: AppSpace.md),
        if (_method == 'mpesa')
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'M-Pesa number',
              helperText: 'A payment request goes to this phone; the member enters their PIN.',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          )
        else ...[
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount received (KES)', prefixIcon: Icon(Icons.money_rounded)),
          ),
          if (_method == 'bank') ...[
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(labelText: 'Bank reference'),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
            title: const Text('Send the member a WhatsApp confirmation'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpace.md),
          FormErrorText(_error!),
        ],
        const SizedBox(height: AppSpace.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy
              ? 'Sending…'
              : _method == 'mpesa'
                  ? 'Send M-Pesa request'
                  : 'Record ${_plan == null ? 'payment' : formatKes(int.tryParse(_amount.text) ?? 0)}'),
        ),
      ],
    );
  }
}
