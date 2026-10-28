import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';

/// One page of members for a search ('' for everyone).
final membersPageProvider = FutureProvider.autoDispose
    .family<({List<MemberCard> members, bool onlyAssigned, int lastPage}), ({String search, int page})>(
  (ref, q) => ref.watch(staffApiProvider).members(search: q.search.isEmpty ? null : q.search, page: q.page),
);

final memberProfileProvider = FutureProvider.autoDispose.family<MemberProfile, int>(
  (ref, id) => ref.watch(staffApiProvider).member(id),
);

final memberNotesProvider = FutureProvider.autoDispose.family<List<TrainerNote>, int>(
  (ref, id) => ref.watch(staffApiProvider).notes(id),
);

final memberTrainingProvider = FutureProvider.autoDispose.family<TrainingSummary?, int>(
  (ref, id) => ref.watch(staffApiProvider).training(id),
);

final trainerDashboardProvider = FutureProvider.autoDispose<TrainerDashboard>(
  (ref) => ref.watch(staffApiProvider).trainerDashboard(),
);
