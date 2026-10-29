import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../desk/desk_providers.dart';
import 'payment_actions.dart';
import 'payment_providers.dart';

/// How the payment flow ended, for the screen that opened it.
class PayOutcome {
  const PayOutcome({required this.payment, required this.checkedIn});

  final PaymentRecord payment;

  /// "Check in & done" checked the member in (or they already were).
  final bool checkedIn;
}

/// Take a payment without leaving the screen: plan, method, then waiting
/// for M-Pesa or done. Pops with a [PayOutcome] once paid.
Future<PayOutcome?> showPaySheet(BuildContext context, {required int memberId}) =>
    showAppSheet<PayOutcome>(context, builder: (_) => PayFlow(memberId: memberId));

/// The same flow as a page, for links from notifications.
class PayScreen extends StatelessWidget {
  const PayScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context) => AppPage(title: 'Take payment', body: PayFlow(memberId: memberId));
}

/// Waits on an M-Pesa request already sent (a link to /payments/{id}).
class PaymentWaitScreen extends ConsumerStatefulWidget {
  const PaymentWaitScreen({super.key, required this.paymentId});

  final int paymentId;

  @override
  ConsumerState<PaymentWaitScreen> createState() => _PaymentWaitScreenState();
}

class _PaymentWaitScreenState extends ConsumerState<PaymentWaitScreen> {
  PaymentRecord? _done;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final done = _done;
    return AppPage(
      title: 'M-Pesa payment',
      body: SheetBody(children: [
        if (done != null)
          _Done(payment: done, memberId: null)
        else if (_failure != null)
          InfoCard(title: 'Not paid', message: _failure!, tone: Tone.warning)
        else
          _MpesaWait(
            paymentId: widget.paymentId,
            firstName: null,
            onPaid: (p) => setState(() => _done = p),
            onFailed: (reason) => setState(() => _failure = reason),
            onStop: () => Navigator.of(context).maybePop(),
          ),
      ]),
    );
  }
}

class PayFlow extends ConsumerWidget {
  const PayFlow({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(paySetupProvider(memberId));
    return AsyncView(
      value: setup,
      onRetry: () => ref.invalidate(paySetupProvider(memberId)),
      data: (s) => _PayFlowBody(member: s.member, plans: s.plans),
    );
  }
}

class _PayFlowBody extends ConsumerStatefulWidget {
  const _PayFlowBody({required this.member, required this.plans});

  final MemberCard member;
  final Plans plans;

  @override
  ConsumerState<_PayFlowBody> createState() => _PayFlowBodyState();
}

class _PayFlowBodyState extends ConsumerState<_PayFlowBody> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final _phone = TextEditingController(text: formatLocalPhone(widget.member.phone));
  Plan? _plan;
  late String _method = widget.plans.mpesaEnabled ? 'mpesa' : 'cash';
  bool _notify = true;
  bool _busy = false;
  String? _error;

  /// The M-Pesa request being waited on, then the finished payment.
  PaymentRecord? _waiting;
  PaymentRecord? _done;

  MemberCard get _member => widget.member;

  @override
  void initState() {
    super.initState();
    // Their last plan, so a renewal is one tap.
    final last = widget.plans.plans.where((p) => p.name == _member.membership?.plan).firstOrNull;
    if (last != null) _choose(last);
  }

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

  int get _amountValue => int.tryParse(_amount.text.trim()) ?? 0;

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
          memberId: _member.id,
          planId: plan.id,
          phone: normalizeKenyanPhone(_phone.text),
        );
        if (mounted) setState(() => _waiting = payment);
        return;
      }
      if (_amountValue < 1) throw const ValidationFailure('Enter the amount received.');
      final payment = await api.payCash(
        memberId: _member.id,
        planId: plan.id,
        amount: _amountValue,
        method: _method,
        reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notify: _notify,
      );
      memberDataChanged(ref);
      if (mounted) setState(() => _done = payment);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    final waiting = _waiting;
    final first = firstName(_member.name);
    return SheetBody(children: [
      if (done != null)
        _Done(payment: done, memberId: _member.id, firstName: first, plan: _plan?.name)
      else if (waiting != null)
        _MpesaWait(
          paymentId: waiting.id,
          firstName: first,
          amount: waiting.amount,
          phone: _phone.text,
          onPaid: (p) {
            memberDataChanged(ref);
            setState(() => _done = p);
          },
          onFailed: (reason) => setState(() {
            _waiting = null;
            _error = 'Not paid. $reason';
          }),
          onStop: () => setState(() => _waiting = null),
        )
      else
        ..._form(context),
    ]);
  }

  List<Widget> _form(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plans = widget.plans;
    final (status, _) = membershipStatus(_member);
    final price = formatKes(_method == 'mpesa' ? (_plan?.price ?? 0) : _amountValue);
    return [
      SheetTitle(
        'Take payment',
        subtitle: '${_member.name} · $status',
        leading: MemberAvatar(initials: _member.initials, photoUrl: _member.photoUrl, seed: _member.id, size: 48),
      ),
      Text('Plan', style: text.titleMedium),
      const SizedBox(height: AppSpace.md),
      for (final plan in plans.plans) ...[
        RadioPillRow(
          title: plan.name,
          detail: [plan.durationLabel, if (plan.category != 'standard') plan.category].where((s) => s.isNotEmpty).join(' · '),
          trailing: _kesNumber(plan.price),
          selected: _plan?.id == plan.id,
          onTap: () => _choose(plan),
        ),
        const SizedBox(height: AppSpace.sm),
      ],
      const SizedBox(height: AppSpace.lg),
      Text('Paid by', style: text.titleMedium),
      const SizedBox(height: AppSpace.md),
      PillSegmented<String>(
        options: [if (plans.mpesaEnabled) ('mpesa', 'M-Pesa'), ('cash', 'Cash'), ('bank', 'Bank')],
        selected: _method,
        onChanged: (m) => setState(() {
          _method = m;
          _error = null;
        }),
      ),
      const SizedBox(height: AppSpace.xl),
      if (_method == 'mpesa')
        AppField(
          label: 'M-Pesa number',
          controller: _phone,
          keyboardType: TextInputType.phone,
          prefixIcon: AppIcons.phone,
          helper: 'A payment request goes to this phone; the member enters their PIN.',
        )
      else ...[
        AppField(
          label: 'Amount received (KES)',
          controller: _amount,
          keyboardType: TextInputType.number,
          prefixIcon: AppIcons.cash,
          onChanged: (_) => setState(() {}),
        ),
        if (_method == 'bank') ...[
          const SizedBox(height: AppSpace.lg),
          AppField(label: 'Bank reference', controller: _reference),
        ],
        const SizedBox(height: AppSpace.sm),
        SwitchRow(
          title: 'Send a WhatsApp confirmation',
          value: _notify,
          onChanged: (v) => setState(() => _notify = v),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpace.lg),
        InfoCard(message: _error!, tone: Tone.warning),
      ],
      const SizedBox(height: AppSpace.xl),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy
            ? (_method == 'mpesa' ? 'Sending…' : 'Recording…')
            : _plan == null
                ? 'Choose a plan'
                : _method == 'mpesa'
                    ? 'Send $price request'
                    : 'Record $price'),
      ),
    ];
  }

  /// "4,000": KES is left out inside the plan list.
  static String _kesNumber(int amount) => formatKes(amount).replaceFirst('KES ', '');
}

/// Polls an M-Pesa request until the member approves or declines it on
/// their phone, with a pulsing phone while it waits.
class _MpesaWait extends ConsumerStatefulWidget {
  const _MpesaWait({
    required this.paymentId,
    required this.firstName,
    required this.onPaid,
    required this.onFailed,
    required this.onStop,
    this.amount,
    this.phone,
  });

  final int paymentId;
  final String? firstName;
  final int? amount;
  final String? phone;
  final ValueChanged<PaymentRecord> onPaid;
  final ValueChanged<String> onFailed;
  final VoidCallback onStop;

  @override
  ConsumerState<_MpesaWait> createState() => _MpesaWaitState();
}

class _MpesaWaitState extends ConsumerState<_MpesaWait> {
  static const _every = Duration(seconds: 4);
  static const _giveUpAfter = Duration(minutes: 2);

  Timer? _timer;
  DateTime _started = DateTime.now();
  PaymentRecord? _payment;

  bool get _timedOut => !(_timer?.isActive ?? false);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _started = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(_every, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final result = await ref.read(staffApiProvider).payment(widget.paymentId);
      if (!mounted) return;
      setState(() => _payment = result.payment);
      switch (result.payment.status) {
        case 'completed':
          _timer?.cancel();
          widget.onPaid(result.payment);
        case 'failed' || 'cancelled' || 'voided':
          _timer?.cancel();
          widget.onFailed(result.failureReason ?? 'The member cancelled or the request expired. Try again, or take cash.');
      }
    } catch (_) {
      // A dropped connection: try again on the next tick.
    }
    if (DateTime.now().difference(_started) > _giveUpAfter) {
      _timer?.cancel();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final amount = widget.amount ?? _payment?.amount;
    final who = widget.firstName ?? firstName(_payment?.member);
    return Semantics(
      liveRegion: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpace.lg),
        _timedOut ? _StatusCircle(icon: AppIcons.waiting, tint: p.warning) : const _PulsingPhone(),
        const SizedBox(height: AppSpace.xl),
        Text(_timedOut ? 'Still waiting' : 'Waiting for $who', style: text.headlineMedium),
        const SizedBox(height: AppSpace.sm),
        Text(
          _timedOut
              ? 'No answer from M-Pesa yet. If $who paid, it shows in your shift once M-Pesa confirms.'
              : '${amount == null ? 'The' : formatKes(amount)} request sent'
                  '${widget.phone == null ? '' : ' to ${formatLocalPhone(widget.phone!)}'}. '
                  'They enter their M-Pesa PIN to finish.',
          style: text.bodyMedium?.copyWith(color: p.muted),
        ),
        const SizedBox(height: AppSpace.xxl),
        if (_timedOut) ...[
          FilledButton(
            onPressed: () => setState(_startPolling),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSizes.button)),
            child: const Text('Check again'),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        // M-Pesa can't take a request back; this only stops waiting here.
        Center(child: TextButton(onPressed: widget.onStop, child: const Text('Stop waiting'))),
      ]),
    );
  }
}

class _PulsingPhone extends StatefulWidget {
  const _PulsingPhone();

  @override
  State<_PulsingPhone> createState() => _PulsingPhoneState();
}

class _PulsingPhoneState extends State<_PulsingPhone> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: AppMotion.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: a still circle.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) {
            final t = Curves.easeOut.transform(_pulse.value);
            return Transform.scale(
              scale: 0.6 + t,
              child: Opacity(
                opacity: _pulse.isAnimating ? 1 - t : 0,
                child: Container(decoration: BoxDecoration(color: p.success.fill, shape: BoxShape.circle)),
              ),
            );
          },
        ),
        _StatusCircle(icon: AppIcons.phone, tint: p.success),
      ]),
    );
  }
}

/// A 64 px circle with an icon, in a tint.
class _StatusCircle extends StatelessWidget {
  const _StatusCircle({required this.icon, required this.tint, this.halo = false});

  final IconData icon;
  final Tint tint;
  final bool halo;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(halo ? 10 : 0),
        decoration: BoxDecoration(color: halo ? tint.fill.withValues(alpha: 0.6) : null, shape: BoxShape.circle),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: halo ? context.palette.sageStrong : tint.fill, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: halo ? context.palette.onSageStrong : tint.on),
        ),
      );
}

/// Paid: the new end date, a receipt, and checking the member in.
class _Done extends ConsumerStatefulWidget {
  const _Done({required this.payment, required this.memberId, this.firstName, this.plan});

  final PaymentRecord payment;

  /// Null when only the payment is known (a notification link).
  final int? memberId;
  final String? firstName;
  final String? plan;

  @override
  ConsumerState<_Done> createState() => _DoneState();
}

class _DoneState extends ConsumerState<_Done> {
  MemberCard? _card;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final id = widget.memberId;
    // The membership's new end date.
    if (id != null) {
      ref.read(staffApiProvider).card(id).then((c) {
        if (mounted) setState(() => _card = c);
      }, onError: (_) {});
    }
  }

  bool get _alreadyIn {
    final today = ref.read(todayCheckInsProvider).value?.checkIns ?? const [];
    return today.any((c) => c.member.id == widget.memberId);
  }

  Future<void> _finish() async {
    final staff = ref.read(staffProvider);
    final id = widget.memberId;
    final first = widget.firstName ?? firstName(widget.payment.member);
    if (id == null || _alreadyIn || !staff.can('checkin.scan')) {
      Navigator.of(context).pop(PayOutcome(payment: widget.payment, checkedIn: id != null && _alreadyIn));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(staffApiProvider).checkIn(memberId: id);
      memberDataChanged(ref);
      if (!mounted) return;
      showToast(context, result.success ? '$first is checked in' : result.message);
      Navigator.of(context).pop(PayOutcome(payment: widget.payment, checkedIn: result.success));
    } catch (e) {
      if (mounted) showToast(context, failureMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final staff = ref.watch(staffProvider);
    final payment = widget.payment;
    final first = widget.firstName ?? firstName(payment.member);
    final plan = widget.plan ?? payment.plan;
    final until = _card?.membership?.expiresAt;
    final canCheckIn = widget.memberId != null && staff.can('checkin.scan') && !_alreadyIn;
    return Semantics(
      liveRegion: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: AppSpace.lg),
        Align(alignment: Alignment.centerLeft, child: _StatusCircle(icon: AppIcons.check, tint: p.success, halo: true)),
        const SizedBox(height: AppSpace.xl),
        Text('${formatKes(payment.amount)} received', style: text.headlineMedium),
        const SizedBox(height: AppSpace.sm),
        Text(
          "$first's ${plan ?? ''} membership is active${until == null ? '' : ' until ${formatShortDate(until)}'}.",
          style: text.bodyMedium?.copyWith(color: p.muted),
        ),
        const SizedBox(height: AppSpace.xxl),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => sendReceipt(context, ref, payment),
              child: const Text('Send receipt'),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : _finish,
              child: Text(canCheckIn ? (_busy ? 'Checking in…' : 'Check in & done') : 'Done'),
            ),
          ),
        ]),
      ]),
    );
  }
}
