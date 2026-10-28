import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../auth/state/session_controller.dart';
import 'desk_providers.dart';

/// A found or scanned member, with what the front desk can do for them.
Future<void> showMemberActions(BuildContext context, MemberCard member) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MemberActions(member: member),
    );

class _MemberActions extends ConsumerStatefulWidget {
  const _MemberActions({required this.member});

  final MemberCard member;

  @override
  ConsumerState<_MemberActions> createState() => _MemberActionsState();
}

class _MemberActionsState extends ConsumerState<_MemberActions> {
  bool _busy = false;
  String? _result;
  bool _ok = false;

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(staffApiProvider).checkIn(memberId: widget.member.id);
      ref.invalidate(todayCheckInsProvider);
      setState(() {
        _ok = result.success;
        _result = result.message;
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _result = failureMessage(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final m = widget.member;
    final p = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MemberTile(member: m),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: [
                    Icon(_ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: _ok ? p.success : p.danger),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Text(_result!, style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.md),
            if (staff.can('checkin.scan') && !_ok)
              FilledButton.icon(
                onPressed: _busy ? null : _checkIn,
                icon: const Icon(Icons.login_rounded),
                label: Text(_busy ? 'Checking in…' : 'Check in'),
              ),
            if (staff.can('payments.record')) ...[
              const SizedBox(height: AppSpace.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(Routes.pay(m.id));
                },
                icon: const Icon(Icons.payments_outlined),
                label: Text(m.isCurrent ? 'Renew or take payment' : 'Take payment'),
              ),
            ],
            // Trainers who are also receptionists can serve anyone at the
            // desk, but only open their own clients' profiles.
            if (staff.browseAllMembers && staff.can('members.view')) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(Routes.member(m.id));
                },
                child: const Text('Open profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
