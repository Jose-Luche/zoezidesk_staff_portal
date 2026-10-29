import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/cards.dart';
import '../../../shared/widgets/controls.dart';
import '../state/session_controller.dart';
import '../widgets/auth_scaffold.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Stack(children: [
          CornerDecoration(),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrandMark(),
            SizedBox(height: AppSpace.xl),
            SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 4)),
          ])),
        ]),
      );
}

/// Email and password, on a staff member's own phone.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final staff = await ref.read(authRepositoryProvider).login(email: _email.text.trim(), password: _password.text);
      ref.read(sessionControllerProvider.notifier).signedIn(staff);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final reason = session is SignedOut ? session.reason : null;

    return AuthScaffold(
      title: 'Sign in',
      subtitle: 'Use the email and password you sign in to ZoeziDesk with on the web.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (reason != null) ...[
              FormErrorText(reason),
              const SizedBox(height: AppSpace.lg),
            ],
            AppField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              prefixIcon: AppIcons.mail,
              hint: 'you@yourgym.co.ke',
              validator: (v) => v != null && v.contains('@') ? null : 'Enter your email address.',
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: 'Password',
              controller: _password,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              prefixIcon: AppIcons.lock,
              suffix: Padding(
                padding: const EdgeInsets.only(right: AppSpace.xs),
                child: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(_showPassword ? AppIcons.hide : AppIcons.show, size: AppIconSize.md),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter your password.' : null,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.lg),
              FormErrorText(_error!),
            ],
            const SizedBox(height: AppSpace.xxl),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Signing in…' : 'Sign in')),
            const SizedBox(height: AppSpace.xl),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : () => context.push(Routes.enrol),
                icon: const Icon(AppIcons.frontDesk, size: AppIconSize.sm),
                label: const Text('Set up as the front desk device'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Makes this phone or tablet the gym's shared front-desk device, with the
/// code a manager shows on the web staff page.
class EnrolScreen extends ConsumerStatefulWidget {
  const EnrolScreen({super.key});

  @override
  ConsumerState<EnrolScreen> createState() => _EnrolScreenState();
}

class _EnrolScreenState extends ConsumerState<EnrolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController(text: 'Front desk');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await ref.read(authRepositoryProvider).enrol(code: _code.text, name: _name.text);
      ref.read(sessionControllerProvider.notifier).enrolled(device);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Front desk device',
      subtitle: 'Staff sign in here with their own PIN, for front-desk work only. '
          'Ask a manager to open Staff → Front Desk Devices on the web and choose Enrol a device.',
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppField(
            label: 'Code from the web',
            controller: _code,
            hint: 'ABCD-2345',
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v ?? '').replaceAll(RegExp('[^A-Za-z0-9]'), '').length == 8 ? null : 'Enter the 8-character code.',
          ),
          const SizedBox(height: AppSpace.lg),
          AppField(
            label: 'Name this device',
            controller: _name,
            hint: 'Front desk',
            textInputAction: TextInputAction.done,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Give the device a name.' : null,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            FormErrorText(_error!),
          ],
          const SizedBox(height: AppSpace.xxl),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Setting up…' : 'Set up this device')),
        ]),
      ),
    );
  }
}
