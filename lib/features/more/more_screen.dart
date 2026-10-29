import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../data/api/staff_api.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/member_tile.dart';
import '../auth/state/session_controller.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../notifications/notifications_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final theme = ref.watch(themeModeProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          ListTile(
            leading: MemberAvatar(
              initials: staff.name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join(),
              size: 48,
            ),
            title: Text(staff.name, style: text.titleMedium),
            subtitle: Text('${staff.roleLabel} · ${staff.gymName}'),
          ),
          if (staff.sharedDevice)
            const Padding(
              padding: EdgeInsets.all(AppSpace.md),
              child: InfoBanner(
                tone: BadgeTone.highlight,
                message: 'You are on the front-desk device: front-desk work only. Reports, '
                    'settings and training records are on your own phone.',
              ),
            ),
          if (staff.can('payments.record', 'payments.view'))
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Shift cash-up'),
              onTap: () => context.push(Routes.shift),
            ),
          // Managers who also train: their clients live here, not in a tab.
          if (staff.can('members.view_assigned') && staff.browseAllMembers)
            ListTile(
              leading: const Icon(Icons.fitness_center_rounded),
              title: const Text('My clients'),
              onTap: () => context.push(Routes.clients),
            ),
          if (!staff.sharedDevice)
            ListTile(
              leading: const Icon(Icons.pin_rounded),
              title: Text(staff.hasPin ? 'Change front-desk PIN' : 'Set front-desk PIN'),
              subtitle: const Text('Used to sign in on the gym\'s front-desk device'),
              onTap: () => context.push(Routes.pin),
            ),
          if (!staff.sharedDevice) const _NotificationsTile(),
          ListTile(
            leading: const Icon(Icons.dark_mode_rounded),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: theme,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('Phone setting')),
              ],
              onChanged: (m) => m == null ? null : ref.read(themeModeProvider.notifier).set(m),
            ),
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Design gallery'),
              onTap: () => context.push(Routes.designGallery),
            ),
          const Divider(),
          ListTile(
            leading: Icon(staff.sharedDevice ? Icons.lock_rounded : Icons.logout_rounded),
            title: Text(staff.sharedDevice ? 'Lock (next person)' : 'Sign out'),
            onTap: () => ref.read(sessionControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

class _NotificationsTile extends ConsumerWidget {
  const _NotificationsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationsControllerProvider);
    if (status == NotificationStatus.unavailable) return const SizedBox.shrink();

    return Column(children: [
      SwitchListTile(
        secondary: const Icon(Icons.notifications_rounded),
        title: const Text('App notifications'),
        subtitle: const Text('Front-desk PIN lockouts and other alerts'),
        value: status != NotificationStatus.off,
        onChanged: (v) => ref.read(notificationsControllerProvider.notifier).setEnabled(v),
      ),
      if (status == NotificationStatus.blocked)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: InfoBanner(
            tone: BadgeTone.warning,
            icon: Icons.notifications_paused_rounded,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN saved.')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Front-desk PIN')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            const Text('Everything done on the front-desk device is recorded against you. Keep your PIN to yourself.'),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Your password'),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'New PIN'),
              validator: pinRule,
            ),
            TextFormField(
              controller: _repeat,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Repeat the PIN'),
              validator: (v) => v == _pin.text ? null : 'The two PINs do not match.',
            ),
            if (_error != null) FormErrorText(_error!),
            const SizedBox(height: AppSpace.lg),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save PIN')),
          ],
        ),
      ),
    );
  }
}
