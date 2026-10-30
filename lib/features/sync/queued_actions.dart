import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/outbox.dart';
import '../classes/classes_screen.dart';
import '../desk/desk_providers.dart';
import '../members/member_providers.dart';

/// The actions that can wait for a connection. Each has an idempotency key
/// the server honours (check-ins, bookings, notes) or is the same however
/// often it is sent (cancelling, ticking off). Payments, registering members
/// and enquiry follow-ups are online only: the last needs the server's
/// idempotency middleware on its route first.
abstract final class QueuedKinds {
  static const checkIn = 'checkin';
  static const book = 'book';
  static const cancelBooking = 'cancel_booking';
  static const attended = 'attended';
  static const note = 'note';
}

void _classChanged(Ref ref, Map<String, dynamic> p) => ref
  ..invalidate(rosterProvider(p['class_id'] as int))
  ..invalidate(classesProvider)
  ..invalidate(todayClassesProvider);

/// Every kind of action that can wait for a connection, by name.
final queuedActionsProvider = Provider<Map<String, QueuedAction>>((_) => _actions);

final _actions = <String, QueuedAction>{
  QueuedKinds.checkIn: QueuedAction(
    send: (api, p, key) async {
      final result = await api.checkIn(
        qrCode: p['qr_code'] as String,
        at: DateTime.parse(p['at'] as String),
        idempotencyKey: key,
      );
      if (!result.success) throw ActionRefused(result.message);
      return result;
    },
    onSent: (ref, _) => ref.invalidate(todayCheckInsProvider),
  ),
  QueuedKinds.book: QueuedAction(
    send: (api, p, key) => api.bookClass(p['class_id'] as int, p['member_id'] as int, idempotencyKey: key),
    onSent: _classChanged,
  ),
  QueuedKinds.cancelBooking: QueuedAction(
    send: (api, p, key) => api.cancelBooking(p['class_id'] as int, p['member_id'] as int, idempotencyKey: key),
    onSent: _classChanged,
  ),
  QueuedKinds.attended: QueuedAction(
    send: (api, p, key) => api.setAttended(
      p['class_id'] as int,
      p['member_id'] as int,
      attended: p['attended'] as bool,
      idempotencyKey: key,
    ),
    onSent: _classChanged,
  ),
  QueuedKinds.note: QueuedAction(
    send: (api, p, key) => api.addNote(
      p['member_id'] as int,
      type: p['type'] as String,
      note: p['note'] as String,
      sessionDate: DateTime.parse(p['session_date'] as String),
      idempotencyKey: key,
    ),
    onSent: (ref, p) => ref
      ..invalidate(memberNotesProvider(p['member_id'] as int))
      ..invalidate(trainerDashboardProvider),
  ),
};
