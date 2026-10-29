import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/lock_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/state/session_controller.dart';
import '../../features/classes/classes_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/design_gallery/design_gallery_screen.dart';
import '../../features/enquiries/enquiries_screen.dart';
import '../../features/enquiries/new_enquiry_screen.dart';
import '../../features/desk/desk_screen.dart';
import '../../features/desk/follow_ups_screen.dart';
import '../../features/desk/scan_screen.dart';
import '../../features/members/member_screen.dart';
import '../../features/members/members_screen.dart';
import '../../features/members/new_member_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/payments/pay_screen.dart';
import '../../features/payments/payment_wait_screen.dart';
import '../../features/payments/shift_screen.dart';
import '../../features/reports/today_screen.dart';
import 'routes.dart';

/// Guard rules, kept pure so they can be unit tested.
String? authRedirect(SessionState session, String location) {
  final signedOutRoute = Routes.signedOutRoutes.contains(location);
  return switch (session) {
    SessionLoading() => location == Routes.splash ? null : Routes.splash,
    // A front-desk device only ever shows its lock screen when nobody is
    // signed in: personal logins (full access) belong on personal phones.
    SignedOut(:final device) when device != null => location == Routes.lock ? null : Routes.lock,
    SignedOut() => signedOutRoute && location != Routes.lock ? null : Routes.login,
    SignedIn(:final staff) => _signedInRedirect(tabsFor(staff), location, signedOutRoute),
  };
}

String? _signedInRedirect(List<AppTab> tabs, String location, bool signedOutRoute) {
  final home = tabs.first.path;
  if (signedOutRoute || location == Routes.splash) return home;
  // A tab this staff member doesn't have (roles changed): their first tab.
  final tab = allTabs.where((t) => t.path == location).firstOrNull;
  if (tab != null && !tabs.any((t) => t.path == tab.path)) return home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<SessionState>(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (_, state) => authRedirect(session.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.enrol, builder: (_, _) => const EnrolScreen()),
      GoRoute(path: Routes.lock, builder: (_, _) => const LockScreen()),
      // Every tab exists; the shell shows only the ones this staff member has.
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const TodayScreen()),
          GoRoute(
            path: Routes.desk,
            builder: (_, _) => const DeskScreen(),
          ),
          GoRoute(path: Routes.members, builder: (_, _) => const MembersScreen()),
          GoRoute(path: Routes.clients, builder: (_, _) => const ClientsScreen()),
          GoRoute(path: Routes.classes, builder: (_, _) => const ClassesScreen()),
          GoRoute(path: Routes.more, builder: (_, _) => const MoreScreen()),
        ],
      ),
      GoRoute(path: Routes.scan, builder: (_, _) => const ScanScreen()),
      GoRoute(path: Routes.shift, builder: (_, _) => const ShiftScreen()),
      GoRoute(path: Routes.newMember, builder: (_, _) => const NewMemberScreen()),
      GoRoute(
        path: '/members/:id',
        builder: (_, state) => MemberScreen(memberId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/members/:id/edit',
        builder: (_, state) => EditMemberScreen(memberId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: Routes.followUps, builder: (_, _) => const FollowUpsScreen()),
      GoRoute(
        path: Routes.enquiries,
        builder: (_, _) => const EnquiriesScreen(),
        routes: [GoRoute(path: 'new', builder: (_, _) => const NewEnquiryScreen())],
      ),
      GoRoute(
        path: '/members/:id/pay',
        builder: (_, state) => PayScreen(memberId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/payments/:id',
        builder: (_, state) => PaymentWaitScreen(paymentId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/classes/:id/roster',
        builder: (_, state) => RosterScreen(classId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: Routes.pin, builder: (_, _) => const PinScreen()),
      if (kDebugMode) GoRoute(path: Routes.designGallery, builder: (_, _) => const DesignGalleryScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});

/// The bottom bar, built from the staff member's permissions.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = tabsFor(ref.watch(staffProvider));
    final index = tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
        ],
      ),
    );
  }
}
