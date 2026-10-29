import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/staff.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/member_tile.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/state_message.dart';
import '../../desk/offline_desk.dart';
import '../state/session_controller.dart';
import '../widgets/auth_scaffold.dart';

final lockScreenStaffProvider = FutureProvider.autoDispose<List<LockScreenStaff>>((ref) async {
  try {
    return await ref.watch(authRepositoryProvider).lockScreenStaff();
  } on UnauthorizedFailure {
    // Revoked on the web: the member list goes now, not when someone taps
    // "Set up again" (a removed tablet may never be touched again).
    await clearOfflineDesk(ref);
    rethrow;
  }
});

/// The front-desk device between people: tap your name, enter your PIN.
class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final staff = ref.watch(lockScreenStaffProvider);
    final reason = session is SignedOut ? session.reason : null;
    final text = Theme.of(context).textTheme;

    // Revoked on the web: this device can no longer be used.
    if (staff.error is UnauthorizedFailure) {
      return Scaffold(
        body: StateMessage(
          icon: Icons.phonelink_erase_rounded,
          title: 'This device was removed',
          message: 'A manager removed it from the gym\'s front-desk devices. Set it up again with a new code.',
          actionLabel: 'Set up again',
          onAction: () => ref.read(sessionControllerProvider.notifier).forgetDevice(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Row(
                  children: [
                    const Expanded(child: BrandMark()),
                    PopupMenuButton<String>(
                      tooltip: 'Device options',
                      onSelected: (_) => _confirmForget(context, ref),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'forget', child: Text('Stop using as front desk')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Text('Who is at the desk?', style: text.headlineLarge),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '${session.device?.name ?? 'Front desk'} · ${session.device?.gymName ?? ''}',
                  style: text.bodyMedium?.copyWith(color: context.palette.textMuted),
                ),
                if (reason != null) ...[
                  const SizedBox(height: AppSpace.md),
                  FormErrorText(reason),
                ],
                const SizedBox(height: AppSpace.lg),
                AsyncView(
                  value: staff,
                  onRetry: () => ref.invalidate(lockScreenStaffProvider),
                  // Inside this screen's ListView, so not a scrolling skeleton.
                  loading: const SkeletonList.inline(itemCount: 2),
                  data: (people) => people.isEmpty
                      ? const StateMessage.empty(
                          title: 'Nobody can sign in yet',
                          message: 'Staff set their PIN in the app on their own phone, or on the web under Staff App PIN.',
                        )
                      // Equal cards sharing the row evenly: two across on a phone,
                      // more on a tablet, every card the same height.
                      : LayoutBuilder(builder: (context, constraints) {
                          const minCard = 150.0;
                          final columns = (constraints.maxWidth / (minCard + AppSpace.md)).floor().clamp(2, 5);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: people.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: AppSpace.md,
                              mainAxisSpacing: AppSpace.md,
                              // Avatar, name and up to two lines of roles.
                              mainAxisExtent: 176 * MediaQuery.textScalerOf(context).scale(1),
                            ),
                            itemBuilder: (_, i) => _PersonButton(
                              person: people[i],
                              onTap: () => _askPin(context, ref, people[i]),
                            ),
                          );
                        }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _askPin(BuildContext context, WidgetRef ref, LockScreenStaff person) async {
    final staff = await showModalBottomSheet<StaffProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PinSheet(person: person),
    );
    if (staff != null) ref.read(sessionControllerProvider.notifier).signedIn(staff);
  }

  Future<void> _confirmForget(BuildContext context, WidgetRef ref) async {
    final unsent = await unsentOfflineCheckIns(ref.read(secureStoreProvider));
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop using this as the front desk?'),
        content: Text([
          'Staff will sign in here with email and password instead. '
              'A manager should also remove the device on the web.',
          if (unsent > 0)
            '${unsent == 1 ? '1 check-in' : '$unsent check-ins'} saved offline and not yet sent '
                'will be deleted. Sign someone in first to send them.',
        ].join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionControllerProvider.notifier).forgetDevice();
  }
}

class _PersonButton extends StatelessWidget {
  const _PersonButton({required this.person, required this.onTap});

  final LockScreenStaff person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MemberAvatar(initials: person.initials, size: 56),
                const SizedBox(height: AppSpace.sm),
                Text(person.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  person.roleLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A number pad for the 4–6 digit PIN. Pops with the signed-in profile.
class PinSheet extends ConsumerStatefulWidget {
  const PinSheet({super.key, required this.person});

  final LockScreenStaff person;

  @override
  ConsumerState<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<PinSheet> {
  static const _maxDigits = 6;
  String _pin = '';
  bool _busy = false;
  String? _error;

  void _press(String digit) {
    if (_busy || _pin.length >= _maxDigits) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.length < 4 || _busy) return;
    setState(() => _busy = true);
    try {
      final staff = await ref.read(authRepositoryProvider).pinLogin(staffId: widget.person.id, pin: _pin);
      if (mounted) Navigator.pop(context, staff);
    } on AppFailure catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = e.message;
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    Widget key(String label, {VoidCallback? onTap, IconData? icon, String? semantics}) => SizedBox(
          width: 88,
          height: 64,
          child: TextButton(
            onPressed: onTap,
            child: icon != null
                ? Icon(icon, semanticLabel: semantics)
                : Text(label, style: text.headlineMedium),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.person.name, style: text.headlineSmall),
            const SizedBox(height: AppSpace.sm),
            Text('Enter your PIN', style: text.bodyMedium?.copyWith(color: p.textMuted)),
            const SizedBox(height: AppSpace.md),
            Semantics(
              label: '${_pin.length} digits entered',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _maxDigits; i++)
                    Container(
                      margin: const EdgeInsets.all(AppSpace.xs + 2),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? p.accentText : null,
                        border: Border.all(color: i < _pin.length ? p.accentText : p.border, width: 2),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.sm),
              FormErrorText(_error!),
            ],
            const SizedBox(height: AppSpace.md),
            for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(d, onTap: () => _press(d))]),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                key('', icon: Icons.backspace_outlined, semantics: 'Delete', onTap: _back),
                key('0', onTap: () => _press('0')),
                key('', icon: Icons.arrow_forward_rounded, semantics: 'Sign in', onTap: _pin.length >= 4 ? _submit : null),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
