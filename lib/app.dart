import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/state/session_controller.dart';
import 'features/notifications/notifications_controller.dart';

class ZoeziStaffApp extends ConsumerWidget {
  const ZoeziStaffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final shared = session is SignedIn && session.staff.sharedDevice;
    // Personal phones only: the front-desk device would show one person's
    // alerts to whoever is at the desk.
    if (session is SignedIn && !shared) ref.watch(notificationsControllerProvider);

    return MaterialApp.router(
      title: 'ZoeziDesk Staff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      builder: (context, child) => _ProfileOnResume(
        child: shared ? IdleLock(child: child!) : child!,
      ),
    );
  }
}

/// Roles change on the web: fetch the profile again whenever the app comes
/// back to the foreground.
class _ProfileOnResume extends ConsumerStatefulWidget {
  const _ProfileOnResume({required this.child});

  final Widget child;

  @override
  ConsumerState<_ProfileOnResume> createState() => _ProfileOnResumeState();
}

class _ProfileOnResumeState extends ConsumerState<_ProfileOnResume> {
  late final _listener = AppLifecycleListener(onResume: () {
    if (ref.read(sessionControllerProvider) is SignedIn) {
      ref.read(sessionControllerProvider.notifier).refreshProfile();
    }
  });

  @override
  void initState() {
    super.initState();
    _listener; // start listening
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// On the front-desk device, an untouched app goes back to the lock screen
/// so the next person can't act as the last one.
class IdleLock extends ConsumerStatefulWidget {
  const IdleLock({super.key, required this.child, this.after = const Duration(minutes: 3)});

  final Widget child;
  final Duration after;

  @override
  ConsumerState<IdleLock> createState() => _IdleLockState();
}

class _IdleLockState extends ConsumerState<IdleLock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(widget.after, () => ref.read(sessionControllerProvider.notifier).signOut());
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _restart(),
        child: widget.child,
      );
}
