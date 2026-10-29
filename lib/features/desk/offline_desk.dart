import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/storage/session_storage.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/staff.dart';
import 'desk_providers.dart';

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
/// are sent, oldest first, as soon as the server answers again.
///
/// The queue is in secure storage and survives locking the front-desk
/// device; signing out on a personal phone deletes the list and the queue
/// (see [clearOfflineDesk]).
class OfflineDesk extends Notifier<OfflineDeskState> {
  static const queueKey = 'offline_checkins';
  static const listMaxAge = Duration(minutes: 30);
  static const tick = Duration(seconds: 30);

  final _members = <String, MemberCard>{};
  Timer? _timer;
  bool _sending = false;
  bool _refreshing = false;

  StaffApi get _api => ref.read(staffApiProvider);
  SecureStore get _store => ref.read(secureStoreProvider);
  OfflineListFile get _file => ref.read(offlineListFileProvider);

  @override
  OfflineDeskState build() {
    _timer = Timer.periodic(tick, (_) => _tick());
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(_start);
    return const OfflineDeskState();
  }

  Future<void> _start() async {
    await _load();
    await _tick();
  }

  Future<void> _tick() async {
    if (!ref.mounted) return;
    await send();
    final saved = state.listSavedAt;
    if (saved == null || DateTime.now().difference(saved) > listMaxAge) await refreshList();
  }

  Future<void> _load() async {
    try {
      final queued = await _store.read(queueKey);
      final list = await _file.read();
      if (!ref.mounted) return;
      DateTime? savedAt;
      if (list != null) {
        final json = jsonDecode(list) as Map<String, dynamic>;
        savedAt = DateTime.parse(json['saved_at'] as String);
        _members
          ..clear()
          ..addEntries([
            for (final m in json['members'] as List)
              MapEntry((m as Map<String, dynamic>)['qr_hash'] as String, MemberCard.fromJson(m)),
          ]);
      }
      state = state.copyWith(
        pending: queued == null
            ? const []
            : [for (final e in jsonDecode(queued) as List) QueuedCheckIn.fromJson(e as Map<String, dynamic>)],
        listSavedAt: savedAt,
        listSize: _members.length,
      );
    } catch (_) {
      // A damaged file: the next refresh replaces it.
    }
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
    final entry = QueuedCheckIn(key: const Uuid().v4(), qrCode: qrCode.trim(), at: DateTime.now(), name: name);
    state = state.copyWith(pending: [...state.pending, entry]);
    await _save();
  }

  /// Sends queued check-ins, oldest first, until one can't reach the server.
  Future<void> send() async {
    if (_sending || state.pending.isEmpty) return;
    _sending = true;
    var sent = false;
    try {
      while (ref.mounted && state.pending.isNotEmpty) {
        final entry = state.pending.first;
        String? refusal;
        String? name = entry.name;
        try {
          final result = await _api.checkIn(qrCode: entry.qrCode, at: entry.at, idempotencyKey: entry.key);
          name = result.member?.name ?? name;
          if (!result.success) refusal = result.message;
        } on ValidationFailure catch (e) {
          refusal = e.message; // e.g. older than 48 hours
        } on AppFailure {
          break; // offline, server trouble or signed out: try again later
        }
        if (!ref.mounted) return;
        sent = true;
        state = state.copyWith(
          pending: state.pending.skip(1).toList(),
          refused: refusal == null
              ? state.refused
              : [...state.refused, RefusedCheckIn(name: name ?? 'Unknown QR code', message: refusal, at: entry.at)],
        );
        await _save();
      }
    } finally {
      _sending = false;
      if (sent && ref.mounted) ref.invalidate(todayCheckInsProvider);
    }
  }

  void dismissRefused() => state = state.copyWith(refused: const []);

  Future<void> _save() =>
      _store.write(queueKey, jsonEncode([for (final e in state.pending) e.toJson()]));
}

/// Watched by the app while someone who may check in offline is signed in;
/// ends with the session (the queue stays in storage for the next one).
final offlineDeskProvider = NotifierProvider.autoDispose<OfflineDesk, OfflineDeskState>(OfflineDesk.new);

/// Signing out on a personal phone: the member list and any unsent
/// check-ins leave with the staff member.
Future<void> clearOfflineDesk(Ref ref) async {
  try {
    await ref.read(offlineListFileProvider).delete();
    await ref.read(secureStoreProvider).delete(OfflineDesk.queueKey);
  } catch (_) {
    // Nothing saved, or storage unavailable.
  }
  ref.invalidate(offlineDeskProvider);
}
