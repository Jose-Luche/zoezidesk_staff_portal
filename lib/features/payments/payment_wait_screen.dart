import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/state_message.dart';
import '../desk/desk_providers.dart';

/// Waits for the member to approve an M-Pesa request on their phone.
class PaymentWaitScreen extends ConsumerStatefulWidget {
  const PaymentWaitScreen({super.key, required this.paymentId});

  final int paymentId;

  @override
  ConsumerState<PaymentWaitScreen> createState() => _PaymentWaitScreenState();
}

class _PaymentWaitScreenState extends ConsumerState<PaymentWaitScreen> {
  static const _every = Duration(seconds: 4);
  static const _giveUpAfter = Duration(minutes: 2);

  Timer? _timer;
  late final DateTime _started = DateTime.now();
  PaymentRecord? _payment;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_every, (_) => _poll());
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
      setState(() {
        _payment = result.payment;
        _failure = result.failureReason;
      });
      if (result.payment.status != 'pending') {
        _timer?.cancel();
        memberDataChanged(ref);
      }
    } catch (_) {
      // A dropped connection: try again on the next tick.
    }
    if (DateTime.now().difference(_started) > _giveUpAfter) _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final waiting = payment == null || payment.status == 'pending';
    final timedOut = waiting && !(_timer?.isActive ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('M-Pesa payment')),
      body: switch (payment?.status) {
        'completed' => StateMessage(
            icon: Icons.check_circle_rounded,
            title: '${formatKes(payment!.amount)} received',
            message: '${payment.member ?? 'The member'}\'s ${payment.plan ?? ''} membership is active.'
                '${payment.reference == null ? '' : ' Receipt ${payment.reference}.'}',
            actionLabel: 'Done',
            onAction: () => context.pop(),
          ),
        'failed' || 'cancelled' => StateMessage(
            icon: Icons.cancel_rounded,
            title: 'Not paid',
            message: _failure ?? 'The member cancelled or the request expired. Try again, or take cash.',
            actionLabel: 'Back',
            onAction: () => context.pop(),
          ),
        _ when timedOut => StateMessage(
            icon: Icons.hourglass_bottom_rounded,
            title: 'Still waiting',
            message: 'No answer from M-Pesa yet. If the member paid, it will show in your shift once M-Pesa confirms.',
            actionLabel: 'Check again',
            onAction: () {
              _timer = Timer.periodic(_every, (_) => _poll());
              _poll();
              setState(() {});
            },
          ),
        _ => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpace.lg),
                  Text('Waiting for the member', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    payment == null
                        ? 'Sending the request…'
                        : 'Ask them to enter their M-Pesa PIN on their phone (${formatKes(payment.amount)}).',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      },
    );
  }
}
