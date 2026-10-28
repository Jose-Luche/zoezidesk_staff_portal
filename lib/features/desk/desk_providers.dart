import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../members/member_providers.dart';
import '../payments/payment_providers.dart';

final todayCheckInsProvider = FutureProvider.autoDispose<({int count, List<TodayCheckIn> checkIns})>(
  (ref) => ref.watch(staffApiProvider).todayCheckIns(),
);

/// Members matching a front-desk search (3 or more characters).
final lookupProvider = FutureProvider.autoDispose.family<List<MemberCard>, String>(
  (ref, query) => query.trim().length < 3 ? Future.value(const []) : ref.watch(staffApiProvider).lookup(query.trim()),
);

/// After a check-in or a payment, everything that shows a member's status or
/// the day's takings is fetched again, so no screen shows the old state.
void memberDataChanged(WidgetRef ref) {
  ref
    ..invalidate(todayCheckInsProvider)
    ..invalidate(lookupProvider)
    ..invalidate(memberProfileProvider)
    ..invalidate(membersPageProvider)
    ..invalidate(trainerDashboardProvider)
    ..invalidate(shiftProvider);
}
