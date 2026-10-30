import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_failure.dart';
import '../../core/storage/session_storage.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/staff.dart';
import '../../data/repositories/outbox.dart';
import '../sync/queued_actions.dart';

/// A check-in made with no connection, waiting to be sent.
class QueuedCheckIn {
  const QueuedCheckIn({required this.key, required this.qrCode, required this.at, this.name});

  factory QueuedCheckIn.fromJson(Map<String, dynamic> json) => QueuedCheckIn(
        key: json['key'] as String,
        qrCode: json['qr_code'] as String,
        at: DateTime.parse(json['at'] as String),
        name: json['name'] as String?,
      );

  Map<String, dynamic> toJson() => {'key': key, 'qr_code': qrCode, 'at': at.toUtc().toIso8601String(), 'name': name};

  /// The idempotency key: a resend after a lost reply is not counted twice.
  final String key;
  final String qrCode;

  /// When the member came.
  final DateTime at;

  /// From the offline list; null when the code wasn't on it.
  final String? name;
}

/// An offline check-in the server refused once it was sent.
class RefusedCheckIn {
  const RefusedCheckIn({required this.name, required this.message, required this.at});

  final String name;
  final String message;
  final DateTime at;
}

class OfflineDeskState {
  const OfflineDeskState({this.pending = const [], this.refused = const [], this.listSavedAt, this.listSize = 0});

  final List<QueuedCheckIn> pending;
  final List<RefusedCheckIn> refused;

  /// When the offline member list was last downloaded; null if never.
  final DateTime? listSavedAt;
  final int listSize;

  OfflineDeskState copyWith({List<QueuedCheckIn>? pending, List<RefusedCheckIn>? refused, DateTime? listSavedAt, int? listSize}) =>
      OfflineDeskState(
        pending: pending ?? this.pending,
        refused: refused ?? this.refused,
        listSavedAt: listSavedAt ?? this.listSavedAt,
        listSize: listSize ?? this.listSize,
      );
}

/// Where the offline list lives: a file, as it can hold thousands of members.
abstract interface class OfflineListFile {
  Future<String?> read();
  Future<void> write(String contents);
  Future<void> delete();
}

class AppSupportListFile implements OfflineListFile {
  const AppSupportListFile();

  Future<File> get _file async => File('${(await getApplicationSupportDirectory()).path}/offline_members.json');

  @override
  Future<String?> read() async {
    final file = await _file;
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String contents) async => (await _file).writeAsString(contents, flush: true);

  @override
  Future<void> delete() async {
    final file = await _file;
    if (await file.exists()) await file.delete();
  }
}

final offlineListFileProvider = Provider<OfflineListFile>((_) => const AppSupportListFile());

/// Who may keep the whole gym's list: the front-desk device, and staff who
/// may browse every member anyway (the server refuses anyone else).
bool canCheckInOffline(StaffProfile staff) =>
    staff.can('checkin.scan') && (staff.sharedDevice || staff.browseAllMembers);

/// Check-ins when the connection drops. The desk keeps a list of members
/// with a current membership (QR codes hashed) and refreshes it every half
/// hour; a scan with no connection is matched against it, the member is let
/// in, and the check-in is queued with the time they came. Queued check-ins
/// wait in the outbox with every other action and are sent, oldest first,
/// as soon as the server answers again.
///
/// The outbox is in the encrypted database and survives locking the
/// front-desk device; signing out on a personal phone deletes the list and
/// the queue (see clearDeviceData).
class OfflineDesk extends Notifier<OfflineDeskState> {
  /// Where the queue was kept before the outbox; moved over on start.
  static const legacyQueueKey = 'offline_checkins';
  static const listMaxAge = Duration(minutes: 30);
  static const tick = Duration(seconds: 30);

  final _members = <String, MemberCard>{};
  Timer? _timer;
  bool _refreshing = false;

  StaffApi get _api => ref.read(staffApiProvider);
  SecureStore get _store => ref.read(secureStoreProvider);
  OfflineListFile get _file => ref.read(offlineListFileProvider);
  OutboxController get _outbox => ref.read(outboxProvider.notifier);

  @override
  OfflineDeskState build() {
    _timer = Timer.periodic(tick, (_) => _tick());
    ref.onDispose(() => _timer?.cancel());
    ref.listen(outboxProvider, (_, items) => _fromOutbox(items));
    Future.microtask(_start);
    return OfflineDeskState(
      pending: _pending(ref.read(outboxProvider)),
      refused: _refused(ref.read(outboxProvider)),
    );
  }

  static List<QueuedCheckIn> _pending(List<OutboxItem> items) => [
        for (final i in items)
          if (i.kind == QueuedKinds.checkIn && i.waiting)
            QueuedCheckIn(
              key: i.key,
              qrCode: i.payload['qr_code'] as String,
              at: DateTime.parse(i.payload['at'] as String),
              name: i.label,
            ),
      ];

  static List<RefusedCheckIn> _refused(List<OutboxItem> items) => [
        for (final i in items)
          if (i.kind == QueuedKinds.checkIn && i.status == OutboxStatus.failed)
            RefusedCheckIn(
              name: i.label ?? 'Unknown QR code',
              message: i.message ?? '',
              at: DateTime.parse(i.payload['at'] as String),
            ),
      ];

  void _fromOutbox(List<OutboxItem> items) =>
      state = state.copyWith(pending: _pending(items), refused: _refused(items));

  Future<void> _start() async {
    await _load();
    await _tick();
  }

  Future<void> _tick() async {
    if (!ref.mounted) return;
    final saved = state.listSavedAt;
    if (saved == null || DateTime.now().difference(saved) > listMaxAge) await refreshList();
  }

  Future<void> _load() async {
    try {
      await _moveLegacyQueue();
      final list = await _file.read();
      if (!ref.mounted || list == null) return;
      final json = jsonDecode(list) as Map<String, dynamic>;
      _members
        ..clear()
        ..addEntries([
          for (final m in json['members'] as List)
            MapEntry((m as Map<String, dynamic>)['qr_hash'] as String, MemberCard.fromJson(m)),
        ]);
      state = state.copyWith(listSavedAt: DateTime.parse(json['saved_at'] as String), listSize: _members.length);
    } catch (_) {
      // A damaged file: the next refresh replaces it.
    }
  }

  /// Check-ins queued by the version before the outbox, kept with their
  /// keys and times so none is lost or counted twice.
  Future<void> _moveLegacyQueue() async {
    final queued = await _store.read(legacyQueueKey);
    if (queued == null) return;
    for (final e in jsonDecode(queued) as List) {
      final c = QueuedCheckIn.fromJson(e as Map<String, dynamic>);
      await _outbox.enqueue(
        QueuedKinds.checkIn,
        {'qr_code': c.qrCode, 'at': c.at.toUtc().toIso8601String()},
        label: c.name,
        key: c.key,
        at: c.at,
      );
    }
    await _store.delete(legacyQueueKey);
  }

  /// Downloads the list again. Offline: keeps the one already saved.
  Future<void> refreshList() async {
    if (_refreshing) return;
    _refreshing = true;
    final file = _file;
    try {
      final list = await _api.offlineList();
      if (!ref.mounted) return;
      final now = DateTime.now();
      await file.write(jsonEncode({
        'saved_at': now.toUtc().toIso8601String(),
        'members': [for (final m in list) m.toJson()],
      }));
      _members
        ..clear()
        ..addEntries([for (final m in list) MapEntry(m.qrHash, m.card)]);
      if (ref.mounted) state = state.copyWith(listSavedAt: now, listSize: _members.length);
    } on AppFailure {
      // Tried again at the next tick.
    } finally {
      _refreshing = false;
    }
  }

  /// The member with this QR code, if the offline list has them with a
  /// membership that hasn't ended.
  MemberCard? match(String qrCode) {
    final card = _members[sha256.convert(utf8.encode(qrCode.trim())).toString()];
    final expires = card?.membership?.expiresAt;
    if (card == null || expires == null) return null;
    final today = DateTime.now();
    return expires.isBefore(DateTime(today.year, today.month, today.day)) ? null : card;
  }

  /// Queues a check-in made with no connection.
  Future<void> record(String qrCode, {String? name}) async {
    final at = DateTime.now();
    await _outbox.enqueue(
      QueuedKinds.checkIn,
      {'qr_code': qrCode.trim(), 'at': at.toUtc().toIso8601String()},
      label: name,
      at: at,
    );
  }

  /// Sends what is waiting now, oldest first, until the server can't be reached.
  Future<void> send() => _outbox.flush(force: true);

  Future<void> dismissRefused() => _outbox.dismissRefused(QueuedKinds.checkIn);
}

/// Watched by the app while someone who may check in offline is signed in;
/// ends with the session (the queue stays in storage for the next one).
final offlineDeskProvider = NotifierProvider.autoDispose<OfflineDesk, OfflineDeskState>(OfflineDesk.new);

/// Deletes the member list (the queue goes with the database, see
/// clearDeviceData): when a staff member signs out of their own phone, and
/// when a phone stops being the front desk (set aside, or revoked on the
/// web), so a lost or retired device doesn't keep the gym's member list.
Future<void> clearOfflineDesk(Ref ref) async {
  try {
    await ref.read(offlineListFileProvider).delete();
    await ref.read(secureStoreProvider).delete(OfflineDesk.legacyQueueKey);
  } catch (_) {
    // Nothing saved, or storage unavailable.
  }
  ref.invalidate(offlineDeskProvider);
}
