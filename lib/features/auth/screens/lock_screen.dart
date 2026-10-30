import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/staff.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/outbox.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/member_tile.dart';
import '../../../shared/widgets/sheet.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/state_message.dart';
import '../state/session_controller.dart';
import '../widgets/auth_scaffold.dart';

final lockScreenStaffProvider = FutureProvider.autoDispose<List<LockScreenStaff>>((ref) async {
  try {
    return await ref.watch(authRepositoryProvider).lockScreenStaff();
  } on UnauthorizedFailure {
    // Revoked on the web: the gym's data goes now, not when someone taps
    // "Set up again" (a removed tablet may never be touched again).
    await clearDeviceData(ref);
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
        body: SafeArea(
          child: Center(
            child: StateMessage(
              icon: AppIcons.lock,
              title: 'This device was removed',
              message: "A manager removed it from the gym's front-desk devices. Set it up again with a new code.",
              actionLabel: 'Set up again',
              onAction: () => ref.read(sessionControllerProvider.notifier).forgetDevice(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(children: [
        const CornerDecoration(),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.lg, AppGutter.cards, AppSpace.xxxl),
                children: [
                  Row(children: [
                    const Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandMark())),
                    PopupMenuButton<String>(
                      tooltip: 'Device options',
                      icon: const Icon(AppIcons.more, size: AppIconSize.md),
                      onSelected: (_) => _confirmForget(context, ref),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'forget', child: Text('Stop using as front desk')),
                      ],
                    ),
                  ]),
                  const SizedBox(height: AppSpace.xxxl + AppSpace.lg),
                  Semantics(header: true, child: Text("Who's at\nthe desk?", style: text.displayLarge)),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    [session.device?.name ?? 'Front desk', ?session.device?.gymName].join(' · '),
                    style: text.bodyMedium?.copyWith(color: context.palette.muted),
                  ),
                  if (reason != null) ...[
                    const SizedBox(height: AppSpace.lg),
                    FormErrorText(reason),
                  ],
                  const SizedBox(height: AppSpace.xxl),
                  AsyncView(
                    value: staff,
                    onRetry: () => ref.invalidate(lockScreenStaffProvider),
                    loading: const SkeletonList.inline(itemCount: 2),
                    data: (people) => people.isEmpty
                        ? const StateMessage.empty(
                            title: 'Nobody can sign in yet',
                            message: 'Staff set their PIN in the app on their own phone, or on the web under Staff App PIN.',
                          )
                        // A name grid: three across on a phone, more on a tablet.
                        : LayoutBuilder(builder: (context, constraints) {
                            const minCell = 104.0;
                            final columns = (constraints.maxWidth / minCell).floor().clamp(3, 6);
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: people.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: AppSpace.lg,
                                crossAxisSpacing: AppSpace.sm,
                                mainAxisExtent: 138 * MediaQuery.textScalerOf(context).scale(1),
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
      ]),
    );
  }

  Future<void> _askPin(BuildContext context, WidgetRef ref, LockScreenStaff person) async {
    final staff = await showAppSheet<StaffProfile>(context, builder: (_) => PinSheet(person: person));
    if (staff != null) ref.read(sessionControllerProvider.notifier).signedIn(staff);
  }

  Future<void> _confirmForget(BuildContext context, WidgetRef ref) async {
    final unsent = await unsentActions(ref.read(appDatabaseProvider), 'desk');
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop using this as the front desk?'),
        content: Text([
          'Staff will sign in here with email and password instead. '
              'A manager should also remove the device on the web.',
          if (unsent > 0)
            '${unsent == 1 ? '1 check-in or class change' : '$unsent check-ins and class changes'} saved offline and not yet sent '
                'will be deleted. Sign someone in first to send them.',
        ].join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep using it')),
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
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Column(children: [
          MemberAvatar(initials: person.initials, seed: person.id, size: 64),
          const SizedBox(height: AppSpace.sm),
          Text(person.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
          Text(person.roleLabel, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
        ]),
      ),
    );
  }
}

/// A pill number pad for the 4–6 digit PIN. Pops with the signed-in profile.
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

    Widget key({String? digit, IconData? icon, String? semantics, VoidCallback? onTap, bool primary = false}) => Padding(
          padding: const EdgeInsets.all(5),
          child: SizedBox(
            width: 88,
            height: 60,
            child: Material(
              color: primary ? (onTap == null ? p.primary.withValues(alpha: 0.45) : p.primary) : p.surface,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Center(
                  child: icon != null
                      ? Icon(icon, semanticLabel: semantics, color: primary ? p.onPrimary : p.text)
                      : Text(digit!, style: text.headlineMedium),
                ),
              ),
            ),
          ),
        );

    return SheetBody(children: [
      Row(children: [
        MemberAvatar(initials: widget.person.initials, seed: widget.person.id, size: 48),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.person.name, style: text.headlineMedium),
            Text('Enter your PIN', style: text.bodyMedium?.copyWith(color: p.muted)),
          ]),
        ),
      ]),
      const SizedBox(height: AppSpace.xxl),
      Semantics(
        label: '${_pin.length} digits entered',
        liveRegion: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _maxDigits; i++)
            AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? p.accent : null,
                border: Border.all(color: i < _pin.length ? p.accent : p.track, width: 2),
              ),
            ),
        ]),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpace.lg),
        FormErrorText(_error!),
      ],
      const SizedBox(height: AppSpace.xl),
      for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) key(digit: d, onTap: () => _press(d))]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        key(icon: AppIcons.backspace, semantics: 'Delete', onTap: _back),
        key(digit: '0', onTap: () => _press('0')),
        key(icon: AppIcons.go, semantics: 'Sign in', primary: true, onTap: _pin.length >= 4 && !_busy ? _submit : null),
      ]),
      if (_busy) ...[const SizedBox(height: AppSpace.md), const LinearProgressIndicator()],
    ]);
  }
}
