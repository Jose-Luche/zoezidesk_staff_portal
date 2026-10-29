import 'package:flutter/material.dart';

import '../../data/models/staff.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const enrol = '/enrol';
  static const lock = '/lock';

  // Tabs
  static const home = '/home';
  static const desk = '/desk';
  static const members = '/members';
  static const clients = '/clients';
  static const classes = '/classes';
  static const more = '/more';

  static const scan = '/desk/scan';
  static const shift = '/shift';
  static const newMember = '/members/new';
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
  const AppTab(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _homeTab = AppTab(Routes.home, 'Today', Icons.insights_outlined, Icons.insights_rounded);
const _deskTab = AppTab(Routes.desk, 'Front desk', Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded);
const _membersTab = AppTab(Routes.members, 'Members', Icons.people_outline_rounded, Icons.people_rounded);
const _clientsTab = AppTab(Routes.clients, 'My clients', Icons.fitness_center_outlined, Icons.fitness_center_rounded);
const _classesTab = AppTab(Routes.classes, 'Classes', Icons.calendar_month_outlined, Icons.calendar_month_rounded);
const _moreTab = AppTab(Routes.more, 'More', Icons.menu_rounded, Icons.menu_rounded);

/// Every tab the app has, in bar order.
const allTabs = [_homeTab, _deskTab, _membersTab, _clientsTab, _classesTab, _moreTab];

/// The tabs this staff member gets, from their permissions (the server checks
/// every request anyway). At most five.
List<AppTab> tabsFor(StaffProfile staff) => [
      if (staff.can('reports.view') && !staff.sharedDevice) _homeTab,
      if (staff.can('checkin.scan')) _deskTab,
      if (staff.can('members.view') && staff.browseAllMembers) _membersTab,
      // Trainers who don't see every member work from their clients instead;
      // managers who also train find "My clients" under More.
      if (staff.can('members.view_assigned') && !staff.browseAllMembers) _clientsTab,
      if (staff.can('classes.view')) _classesTab,
      _moreTab,
    ];
