import '../../data/models/staff.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const enrol = '/enrol';
  static const lock = '/lock';

  // Tabs
  static const home = '/home';
  static const members = '/members';
  static const clients = '/clients';
  static const classes = '/classes';

  /// The old front-desk tab, now the Desk home. Kept for notification links.
  static const desk = '/desk';

  static const more = '/more';
  static const scan = '/desk/scan';
  static const shift = '/shift';
  static String member(int id) => '/members/$id';
  static String editMember(int id) => '/members/$id/edit';
  static const followUps = '/follow-ups';
  static const enquiries = '/enquiries';
  static const newEnquiry = '/enquiries/new';
  static String pay(int memberId) => '/members/$memberId/pay';
  static String payment(int paymentId) => '/payments/$paymentId';
  static String roster(int classId) => '/classes/$classId/roster';
  static const pin = '/more/pin';
  static const designGallery = '/dev/design';

  static const signedOutRoutes = {login, enrol, lock};
}

/// A bottom-bar tab.
class AppTab {
  const AppTab(this.path, this.label);

  final String path;
  final String label;
}

const _homeTab = AppTab(Routes.home, 'Home');
const _membersTab = AppTab(Routes.members, 'Members');
const _clientsTab = AppTab(Routes.clients, 'My clients');
const _classesTab = AppTab(Routes.classes, 'Classes');

/// Every tab the app has, in bar order.
const allTabs = [_homeTab, _membersTab, _clientsTab, _classesTab];

/// The tabs this staff member gets, from their permissions (the server checks
/// every request anyway): Home, then Members (or My clients for trainers who
/// can't browse everyone), then Classes. Never more than three; everything
/// else lives under More, from the Home header.
List<AppTab> tabsFor(StaffProfile staff) => [
      _homeTab,
      if (staff.can('members.view') && staff.browseAllMembers)
        _membersTab
      else if (staff.can('members.view_assigned'))
        _clientsTab,
      if (staff.can('classes.view')) _classesTab,
    ];

/// The shapes Home takes, one per kind of work (design.md §4).
enum HomeVariant {
  desk('Desk'),
  training('Training'),
  owner('Owner');

  const HomeVariant(this.label);

  final String label;
}

/// Which Homes this staff member has, in switcher order. The shared
/// front-desk device only ever has Desk.
List<HomeVariant> homeVariantsFor(StaffProfile staff) => [
      if (staff.can('checkin.scan')) HomeVariant.desk,
      if (!staff.sharedDevice && staff.can('members.view_assigned') && !staff.browseAllMembers) HomeVariant.training,
      if (!staff.sharedDevice && staff.can('reports.view')) HomeVariant.owner,
    ];

/// The Home shown before someone picks one: the widest view they have.
HomeVariant? defaultHomeVariant(List<HomeVariant> variants) => variants.isEmpty
    ? null
    : variants.contains(HomeVariant.owner)
        ? HomeVariant.owner
        : variants.contains(HomeVariant.training)
            ? HomeVariant.training
            : variants.first;
