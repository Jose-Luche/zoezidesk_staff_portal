import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../features/auth/state/session_controller.dart';
import '../../features/sync/queued_actions.dart';
import '../api/staff_api.dart';
import '../local/app_database.dart';
import 'read_cache.dart';

enum OutboxStatus { pending, sending, sent, failed }

/// An action waiting to reach the server, or refused by it.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.key,
    required this.status,
    required this.createdAt,
    this.label,
    this.message,
  });

  factory OutboxItem.fromRow(OutboxRow row) => OutboxItem(
        id: row.id,
        kind: row.kind,
        payload: jsonDecode(row.payload) as Map<String, dynamic>,
        key: row.idempotencyKey,
        status: OutboxStatus.values.byName(row.status),
        createdAt: row.createdAt,
        label: row.label,
        message: row.message,
      );

  final int id;
  final String kind;
  final Map<String, dynamic> payload;

  /// The idempotency key, the same on every try.
  final String key;
  final OutboxStatus status;
  final DateTime createdAt;
  final String? label;

  /// Why the server refused it.
  final String? message;

  /// Not sent yet: shown as pending.
  bool get waiting => status == OutboxStatus.pending || status == OutboxStatus.sending;
}

/// How to send one kind of action, and what to refresh once it is in.
class QueuedAction {
  const QueuedAction({required this.send, this.onSent});

  /// Throws [ActionRefused] or AppFailure; returns the server's answer.
  final Future<Object?> Function(StaffApi api, Map<String, dynamic> payload, String key) send;
  final void Function(Ref ref, Map<String, dynamic> payload)? onSent;
}

/// The server answered and said no (`success: false`).
class ActionRefused implements Exception {
  const ActionRefused(this.message);

  final String message;
}

/// What submitting an action came to.
sealed class Delivery {
  const Delivery();
}

/// The server has it; [result] is its answer.
class Delivered extends Delivery {
  const Delivered(this.result);

  final Object? result;
}

/// The server said no.
class Refused extends Delivery {
  const Refused(this.message);

  final String message;
}

/// No connection: it is saved and goes when the server answers again.
class Queued extends Delivery {
  const Queued();
}

/// When the phone's connection changes to one that may work: a hint to try
/// now rather than at the next tick. A failed request is the real signal.
final connectionBackProvider = Provider<Stream<void>>(
  (_) => Connectivity()
      .onConnectivityChanged
      .where((r) => r.any((c) => c != ConnectivityResult.none))
      .map((_) {}),
);

/// Actions done with no connection, or whose connection dropped, sent to
/// the server in order, oldest first, as soon as it answers: on each new
/// action, every half minute (backing off after failures), and when the
/// phone's connection comes back. An action the server refuses stays, with
/// its reason, until it is dismissed. State: this person's (or the desk's)
/// waiting and refused actions, oldest first.
class OutboxController extends Notifier<List<OutboxItem>> {
  static const tick = Duration(seconds: 30);
  static const maxBackoff = Duration(minutes: 5);

  final _random = Random();
  final _results = <int, Object?>{};
  Future<void>? _flushing;

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String? _owner;

  @override
  List<OutboxItem> build() {
    final owner = _owner = ref.watch(sessionControllerProvider.select(readCacheOwnerOf));
    if (owner == null) return const [];
    final db = ref.watch(appDatabaseProvider);
    final rows = (db.select(db.outbox)
          ..where((o) => o.owner.equals(owner) & o.status.isNotValue(OutboxStatus.sent.name))
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .watch()
        .listen((rows) => state = [for (final r in rows) OutboxItem.fromRow(r)], onError: (_) {});
    final timer = Timer.periodic(tick, (_) => flush());
    final back = ref.watch(connectionBackProvider).listen((_) => flush(force: true));
    ref.onDispose(() {
      rows.cancel();
      timer.cancel();
      back.cancel();
    });
    Future.microtask(() => flush(force: true));
    return const [];
  }

  /// Saves [kind] to be sent, without trying it now. Returns its id.
  Future<int> enqueue(String kind, Map<String, dynamic> payload, {String? label, String? key, DateTime? at}) {
    final owner = _owner;
    if (owner == null) throw StateError('Nobody is signed in');
    return _db.into(_db.outbox).insert(OutboxCompanion.insert(
          owner: owner,
          kind: kind,
          payload: jsonEncode(payload),
          idempotencyKey: key ?? const Uuid().v4(),
          label: Value(label),
          status: OutboxStatus.pending.name,
          createdAt: at ?? DateTime.now(),
        ));
  }

  /// Saves [kind] and sends it now, after anything older still waiting. A
  /// refusal is said there and then, so it isn't kept for later.
  Future<Delivery> submit(String kind, Map<String, dynamic> payload, {String? label}) async {
    final id = await enqueue(kind, payload, label: label);
    await flush(force: true);
    final row = await (_db.select(_db.outbox)..where((o) => o.id.equals(id))).getSingleOrNull();
    switch (row?.status) {
      case 'sent':
        return Delivered(_results.remove(id));
      case 'failed':
        await (_db.delete(_db.outbox)..where((o) => o.id.equals(id))).go();
        return Refused(row!.message ?? 'The server refused this.');
      default:
        return const Queued();
    }
  }

  /// Sends what is waiting, oldest first, until the server can't be reached.
  /// [force] ignores the back-off (a new action, or the connection is back).
  Future<void> flush({bool force = false}) {
    final running = _flushing;
    if (running != null) return running;
    return _flushing = _flush(force).whenComplete(() => _flushing = null);
  }

  Future<void> _flush(bool force) async {
    final owner = _owner;
    final actions = ref.read(queuedActionsProvider);
    final api = ref.read(staffApiProvider);
    final db = _db;
    while (ref.mounted && owner != null) {
      final row = await (db.select(db.outbox)
            ..where((o) => o.owner.equals(owner) & o.status.equals(OutboxStatus.pending.name))
            ..orderBy([(o) => OrderingTerm.asc(o.id)])
            ..limit(1))
          .getSingleOrNull();
      if (row == null) return;
      final next = row.nextAttemptAt;
      if (!force && next != null && next.isAfter(DateTime.now())) return;

      final action = actions[row.kind];
      if (action == null) {
        await _set(row.id, OutboxStatus.failed, message: 'This app version can no longer send it.');
        continue;
      }
      await _set(row.id, OutboxStatus.sending);
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      try {
        _results[row.id] = await action.send(api, payload, row.idempotencyKey);
        await _set(row.id, OutboxStatus.sent);
        if (ref.mounted) action.onSent?.call(ref, payload);
      } on ActionRefused catch (e) {
        await _set(row.id, OutboxStatus.failed, message: e.message);
      } on AppFailure catch (e) {
        if (!_later(e)) {
          await _set(row.id, OutboxStatus.failed, message: e.message);
          continue;
        }
        final attempts = row.attempts + 1;
        await (db.update(db.outbox)..where((o) => o.id.equals(row.id))).write(OutboxCompanion(
              status: Value(OutboxStatus.pending.name),
              attempts: Value(attempts),
              nextAttemptAt: Value(DateTime.now().add(backoff(attempts))),
            ));
        return; // the server can't be reached; the rest wait their turn
      } catch (_) {
        // Not something sending again would fix.
        await _set(row.id, OutboxStatus.failed, message: 'Something went wrong sending this.');
      }
    }
  }

  /// 5s, 10s, 20s … up to 5 minutes, plus up to a second of jitter.
  Duration backoff(int attempts) {
    final seconds = min(5 * pow(2, attempts - 1).toInt(), maxBackoff.inSeconds);
    return Duration(seconds: seconds, milliseconds: _random.nextInt(1000));
  }

  /// Worth trying again later, rather than a refusal.
  static bool _later(AppFailure e) => switch (e) {
        NetworkFailure() || TimeoutFailure() || RateLimitedFailure() || UnauthorizedFailure() => true,
        // 409: the same key is still being handled. No status: no answer.
        ServerFailure(:final statusCode) => statusCode == null || statusCode >= 500 || statusCode == 409,
        _ => false,
      };

  Future<void> _set(int id, OutboxStatus status, {String? message}) =>
      (_db.update(_db.outbox)..where((o) => o.id.equals(id)))
          .write(OutboxCompanion(status: Value(status.name), message: Value(message)));

  /// How many are waiting, of [kind] or of any kind, read from the database
  /// (the state follows it a moment later).
  Future<int> waitingCount({String? kind}) async {
    final owner = _owner;
    if (owner == null) return 0;
    final rows = await (_db.select(_db.outbox)
          ..where((o) =>
              o.owner.equals(owner) &
              o.status.isIn([OutboxStatus.pending.name, OutboxStatus.sending.name]) &
              (kind == null ? const Constant(true) : o.kind.equals(kind))))
        .get();
    return rows.length;
  }

  /// Clears refused actions of [kind] once they have been seen.
  Future<void> dismissRefused(String kind) {
    final owner = _owner;
    if (owner == null) return Future.value();
    return (_db.delete(_db.outbox)
          ..where((o) => o.owner.equals(owner) & o.kind.equals(kind) & o.status.equals(OutboxStatus.failed.name)))
        .go();
  }
}

/// Watched by the app while someone is signed in.
final outboxProvider = NotifierProvider<OutboxController, List<OutboxItem>>(OutboxController.new);

/// How many actions [owner] has waiting, read from the database (for the
/// lock screen, where nobody is signed in).
Future<int> unsentActions(AppDatabase db, String owner) async {
  try {
    final count = db.outbox.id.count();
    final query = db.selectOnly(db.outbox)
      ..addColumns([count])
      ..where(db.outbox.owner.equals(owner) & db.outbox.status.isIn(['pending', 'sending']));
    final row = await query.getSingle();
    final n = row.read(count);
    return n ?? 0;
  } catch (_) {
    return 0;
  }
}
