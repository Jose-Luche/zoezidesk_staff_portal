import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/utils/cache.dart';
import 'data/repositories/outbox.dart';
import 'features/auth/state/session_controller.dart';
import 'features/classes/classes_screen.dart';
import 'features/desk/offline_desk.dart';
import 'features/members/member_providers.dart';
import 'features/notifications/notifications_controller.dart';
import 'shared/widgets/toast.dart';

class ZoeziStaffApp extends ConsumerWidget {
  const ZoeziStaffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final shared = session is SignedIn && session.staff.sharedDevice;
    // Personal phones only: the front-desk device would show one person's
    // alerts to whoever is at the desk.
    if (session is SignedIn && !shared) ref.watch(notificationsControllerProvider);
    // Actions done offline go as soon as the server answers.
    if (session is SignedIn) ref.watch(outboxProvider);
    if (session is SignedIn && canCheckInOffline(session.staff)) ref.watch(offlineDeskProvider);
    ref.listen(cacheOwnerProvider, (_, owner) {
      if (owner != null) _prefetchTabs(ref);
    });

    return MaterialApp.router(
      title: 'ZoeziDesk Staff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _ProfileOnResume(
        child: ToastHost(child: shared ? IdleLock(child: child!) : child!),
      ),
    );
  }
}

/// Loads the other tabs' first screen as soon as someone signs in, so the
/// first switch to them shows data instead of a skeleton. They stay cached
/// (see [CacheFor]); a failure here is left for the tab to show.
void _prefetchTabs(WidgetRef ref) {
  final session = ref.read(sessionControllerProvider);
  if (session is! SignedIn) return;
  for (final tab in tabsFor(session.staff)) {
    switch (tab.path) {
      case Routes.members:
        ref.read(membersPageProvider((search: '', page: 1)).future).ignore();
      case Routes.clients:
        ref.read(trainerDashboardProvider.future).ignore();
      case Routes.classes:
        ref.read(classesProvider.future).ignore();
    }
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
