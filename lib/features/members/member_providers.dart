import '../../data/api/staff_api.dart';
import '../../data/repositories/read_cache.dart';

/// One page of members for a search ('' for everyone).
final membersPageProvider = cachedReadFamily(
  (_, ({String search, int page}) q) => StaffReads.members(search: q.search.isEmpty ? null : q.search, page: q.page),
);

final memberProfileProvider = cachedReadFamily((_, int id) => StaffReads.member(id));

final memberNotesProvider = cachedReadFamily((_, int id) => StaffReads.notes(id));

final memberTrainingProvider = cachedReadFamily((_, int id) => StaffReads.training(id));

final trainerDashboardProvider = cachedRead((_) => StaffReads.trainerDashboard);
