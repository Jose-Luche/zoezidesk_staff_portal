import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/router/app_router.dart';
import 'package:zoezidesk_staff/core/router/routes.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';
import 'package:zoezidesk_staff/features/auth/state/session_controller.dart';

import '../../helpers/fakes.dart';

void main() {
  const device = FrontDeskDevice(id: 1, name: 'Front desk', gymName: 'Test Gym');

  List<String> tabs(StaffProfile staff) => [for (final t in tabsFor(staff)) t.path];

  group('tabs follow permissions', () {
    test('receptionists get the front desk, members and classes', () {
      expect(tabs(staffWith(receptionistPermissions)), [Routes.desk, Routes.members, Routes.classes, Routes.more]);
    });

    test('trainers work from their clients', () {
      expect(tabs(staffWith(trainerPermissions, browseAll: false)), [Routes.desk, Routes.clients, Routes.classes, Routes.more]);
    });

    test('trainer-receptionists get the desk and their clients, never the member list', () {
      final both = staffWith({...receptionistPermissions, ...trainerPermissions}, browseAll: false);
      expect(tabs(both), [Routes.desk, Routes.clients, Routes.classes, Routes.more]);
    });

    test('owners start on today', () {
      expect(tabs(staffWith(ownerPermissions)), [Routes.home, Routes.desk, Routes.members, Routes.classes, Routes.more]);
    });

    test('nobody gets reports on the shared front-desk device', () {
      expect(tabs(staffWith(ownerPermissions, shared: true)), isNot(contains(Routes.home)));
    });

    test('never more than five tabs', () {
      final everything = staffWith({...ownerPermissions, ...trainerPermissions});
      expect(tabsFor(everything).length, lessThanOrEqualTo(5));
    });
  });

  group('redirects', () {
    test('loading shows the splash', () {
      expect(authRedirect(const SessionLoading(), Routes.desk), Routes.splash);
    });

    test('signed out on a personal phone goes to the email login', () {
      expect(authRedirect(const SignedOut(), Routes.members), Routes.login);
      expect(authRedirect(const SignedOut(), Routes.login), isNull);
      expect(authRedirect(const SignedOut(), Routes.enrol), isNull);
      expect(authRedirect(const SignedOut(), Routes.lock), Routes.login);
    });

    test('a front-desk device only shows its lock screen when signed out', () {
      expect(authRedirect(const SignedOut(device: device), Routes.login), Routes.lock);
      expect(authRedirect(const SignedOut(device: device), Routes.enrol), Routes.lock);
      expect(authRedirect(const SignedOut(device: device), Routes.lock), isNull);
    });

    test('signing in lands on the first tab', () {
      expect(authRedirect(SignedIn(staffWith(ownerPermissions)), Routes.login), Routes.home);
      expect(authRedirect(SignedIn(staffWith(receptionistPermissions), device: device), Routes.lock), Routes.desk);
    });

    test('a tab the staff member no longer has sends them to their first tab', () {
      final trainer = SignedIn(staffWith(trainerPermissions, browseAll: false));
      expect(authRedirect(trainer, Routes.members), Routes.desk);
      expect(authRedirect(trainer, Routes.home), Routes.desk);
      expect(authRedirect(trainer, Routes.clients), isNull);
      // Screens outside the tabs are checked by the server.
      expect(authRedirect(trainer, Routes.member(5)), isNull);
    });
  });
}
