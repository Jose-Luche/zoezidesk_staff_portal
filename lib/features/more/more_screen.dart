import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../desk/follow_ups_screen.dart';
import '../notifications/notifications_controller.dart';

/// Everything that isn't a tab (design.md §4): the shift, follow-ups,
/// enquiries, the PIN, notifications and theme, and signing out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final text = Theme.of(context).textTheme;

    return AppPage(
      title: 'More',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.sm, AppGutter.heading, AppSpace.lg),
            child: Row(children: [
              MemberAvatar(initials: initialsOf(staff.name), seed: staff.id, size: 60),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(staff.name, style: text.headlineMedium),
                  Text('${staff.roleLabel} · ${staff.gymName}', style: text.bodySmall),
                ]),
              ),
            ]),
          ),
          if (staff.sharedDevice)
            const Padding(
              padding: EdgeInsets.fromLTRB(AppGutter.cards, 0, AppGutter.cards, AppSpace.md),
              child: InfoCard(
                tone: Tone.warning,
                icon: AppIcons.frontDesk,
                message: 'You are on the front-desk device: front-desk work only. Reports, '
                    'settings and training records are on your own phone.',
              ),
            ),
          const SectionHeading('Work'),
          if (staff.can('payments.record', 'payments.view'))
            _Entry(icon: AppIcons.receipt, title: 'My shift', subtitle: 'Cash-up for the day', onTap: () => context.push(Routes.shift)),
          if (staff.can('checkin.scan') || staff.can('members.view_assigned'))
            _Entry(
              icon: AppIcons.history,
              title: 'Follow-ups',
              subtitle: 'Ending in 7 days or lapsed',
              onTap: () => showFollowUpsSheet(context),
            ),
          // Walk-in enquiries need the CRM in the gym's plan.
          if (staff.can('leads.capture') && staff.hasCrm)
            _Entry(
              icon: AppIcons.enquiries,
              title: 'Enquiries',
              subtitle: 'Walk-ins to call back',
              onTap: () => context.push(Routes.enquiries),
            ),
          // Managers who also train: their clients live here, not in a tab.
          if (staff.can('members.view_assigned') && staff.browseAllMembers)
            _Entry(icon: AppIcons.training, title: 'My clients', onTap: () => context.push(Routes.clients)),
          const SectionHeading('This phone'),
          if (!staff.sharedDevice)
            _Entry(
              icon: AppIcons.pin,
              title: staff.hasPin ? 'Change front-desk PIN' : 'Set front-desk PIN',
              subtitle: "Used to sign in on the gym's front-desk device",
              onTap: () => context.push(Routes.pin),
            ),
          if (!staff.sharedDevice) const _NotificationsEntry(),
          const _ThemeEntry(),
          if (kDebugMode)
            _Entry(icon: AppIcons.palette, title: 'Design gallery', onTap: () => context.push(Routes.designGallery)),
          const SizedBox(height: AppSpace.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
            child: OutlinedButton.icon(
              onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
              icon: Icon(staff.sharedDevice ? AppIcons.lock : AppIcons.signOut, size: AppIconSize.sm),
              label: Text(staff.sharedDevice ? 'Lock for the next person' : 'Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.title, this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGutter.rows),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: context.palette.surface, shape: BoxShape.circle),
            child: Icon(icon, size: AppIconSize.md),
          ),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: onTap == null ? null : const Icon(AppIcons.forward, size: AppIconSize.sm),
        ),
      );
}

class _ThemeEntry extends ConsumerWidget {
  const _ThemeEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(AppGutter.cards, AppSpace.sm, AppGutter.cards, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpace.sm, bottom: AppSpace.sm),
            child: Text('Theme', style: Theme.of(context).textTheme.titleSmall),
          ),
          PillSegmented<ThemeMode>(
            options: const [(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'Phone setting')],
            selected: ref.watch(themeModeProvider),
            onChanged: ref.read(themeModeProvider.notifier).set,
          ),
        ]),
      );
}

class _NotificationsEntry extends ConsumerWidget {
  const _NotificationsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationsControllerProvider);
    if (status == NotificationStatus.unavailable) return const SizedBox.shrink();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppGutter.heading),
        child: SwitchRow(
          title: 'App notifications',
          subtitle: 'Class changes, the evening summary and PIN lockouts',
          value: status != NotificationStatus.off,
          onChanged: (v) => ref.read(notificationsControllerProvider.notifier).setEnabled(v),
        ),
      ),
      if (status == NotificationStatus.blocked)
        const Padding(
          padding: EdgeInsets.fromLTRB(AppGutter.cards, AppSpace.xs, AppGutter.cards, AppSpace.sm),
          child: InfoCard(
            tone: Tone.warning,
            icon: AppIcons.bellOff,
            message: 'Your phone is blocking notifications from ZoeziDesk Staff. Allow them in the '
                "phone's Settings, under Apps > ZoeziDesk Staff > Notifications.",
          ),
        ),
    ]);
  }
}

/// Set or change the PIN for the front-desk device. Needs the password.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_password, _pin, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(staffApiProvider).setPin(password: _password.text, pin: _pin.text);
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      showToast(context, 'PIN saved');
      context.pop();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? pinRule(String? v) => RegExp(r'^\d{4,6}$').hasMatch(v ?? '') ? null : 'Use 4 to 6 digits.';
    return AppPage(
      title: 'Front-desk PIN',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.sm, AppGutter.heading, AppSpace.xxxl),
          children: [
            Text(
              'Everything done on the front-desk device is recorded against you. Keep your PIN to yourself.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
            ),
            const SizedBox(height: AppSpace.xxl),
            AppField(
              label: 'Your password',
              controller: _password,
              obscureText: true,
              validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: 'New PIN',
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              validator: pinRule,
            ),
            const SizedBox(height: AppSpace.sm),
            AppField(
              label: 'Repeat the PIN',
              controller: _repeat,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              validator: (v) => v == _pin.text ? null : 'The two PINs do not match.',
            ),
            if (_error != null) ...[const SizedBox(height: AppSpace.lg), FormErrorText(_error!)],
            const SizedBox(height: AppSpace.xxl),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save PIN')),
          ],
        ),
      ),
    );
  }
}
