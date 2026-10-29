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
    test('receptionists get home, members and classes', () {
      expect(tabs(staffWith(receptionistPermissions)), [Routes.home, Routes.members, Routes.classes]);
    });

    test('trainers work from their clients', () {
      expect(tabs(staffWith(trainerPermissions, browseAll: false)), [Routes.home, Routes.clients, Routes.classes]);
    });

    test('trainer-receptionists get their clients, never the member list', () {
      final both = staffWith({...receptionistPermissions, ...trainerPermissions}, browseAll: false);
      expect(tabs(both), [Routes.home, Routes.clients, Routes.classes]);
    });

    test('owners get home, members and classes', () {
      expect(tabs(staffWith(ownerPermissions)), [Routes.home, Routes.members, Routes.classes]);
    });

    test('never more than three tabs', () {
      final everything = staffWith({...ownerPermissions, ...trainerPermissions});
      expect(tabsFor(everything).length, lessThanOrEqualTo(3));
    });
  });

  group('home follows the work', () {
    List<HomeVariant> homes(StaffProfile staff) => homeVariantsFor(staff);

    test('receptionists get the desk', () {
      expect(homes(staffWith(receptionistPermissions)), [HomeVariant.desk]);
    });

    test('trainers on their own phone get the desk and training, training first', () {
      final trainer = staffWith(trainerPermissions, browseAll: false);
      expect(homes(trainer), [HomeVariant.desk, HomeVariant.training]);
      expect(defaultHomeVariant(homes(trainer)), HomeVariant.training);
    });

    test('owners start on their figures', () {
      final owner = staffWith(ownerPermissions);
      expect(homes(owner), [HomeVariant.desk, HomeVariant.owner]);
      expect(defaultHomeVariant(homes(owner)), HomeVariant.owner);
    });

    test('the shared front-desk device only ever has the desk', () {
      expect(homes(staffWith(ownerPermissions, shared: true)), [HomeVariant.desk]);
      expect(homes(staffWith(trainerPermissions, browseAll: false, shared: true)), [HomeVariant.desk]);
    });

    test('managers who also train keep their clients under More, not on Home', () {
      expect(homes(staffWith({...ownerPermissions, ...trainerPermissions})), isNot(contains(HomeVariant.training)));
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

    test('signing in lands on home', () {
      expect(authRedirect(SignedIn(staffWith(ownerPermissions)), Routes.login), Routes.home);
      expect(authRedirect(SignedIn(staffWith(receptionistPermissions), device: device), Routes.lock), Routes.home);
    });

    test('a tab the staff member no longer has sends them home', () {
      final trainer = SignedIn(staffWith(trainerPermissions, browseAll: false));
      expect(authRedirect(trainer, Routes.members), Routes.home);
      expect(authRedirect(trainer, Routes.home), isNull);
      expect(authRedirect(trainer, Routes.clients), isNull);
      // Screens outside the tabs are checked by the server.
      expect(authRedirect(trainer, Routes.member(5)), isNull);
    });
  });
}
