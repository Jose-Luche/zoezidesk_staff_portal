import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/repositories/read_cache.dart';

/// The member and the plans, to take a payment.
final paySetupProvider = FutureProvider.autoDispose.family<({MemberCard member, Plans plans}), int>((ref, memberId) async {
  final api = ref.watch(staffApiProvider);
  final (member, plans) = await (api.card(memberId), api.plans()).wait;
  return (member: member, plans: plans);
});

/// The cash-up for a day, and for whom (null: yourself).
typedef ShiftQuery = ({DateTime day, int? staffId});

final shiftQueryProvider = NotifierProvider.autoDispose<ShiftQueryController, ShiftQuery>(ShiftQueryController.new);

class ShiftQueryController extends Notifier<ShiftQuery> {
  @override
  ShiftQuery build() {
    final now = DateTime.now();
    return (day: DateTime(now.year, now.month, now.day), staffId: null);
  }

  void setDay(DateTime day) => state = (day: day, staffId: state.staffId);

  void setStaff(int? staffId) => state = (day: state.day, staffId: staffId);
}

final shiftProvider = cachedRead((ref) {
  final q = ref.watch(shiftQueryProvider);
  return StaffReads.shift(date: q.day, staffId: q.staffId);
});
