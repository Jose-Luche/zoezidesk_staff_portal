import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../core/utils/cache.dart';
import '../../features/auth/state/session_controller.dart';
import '../api/staff_api.dart';
import '../local/app_database.dart';

/// A refresh failed and the screen is showing what was saved at [savedAt].
class OutOfDate implements Exception {
  const OutOfDate(this.cause, this.savedAt);

  /// Why the refresh failed, usually an AppFailure.
  final Object cause;
  final DateTime savedAt;

  @override
  String toString() => 'OutOfDate($cause, saved $savedAt)';
}

/// Whose rows the cache reads and writes: `desk` on the front-desk device,
/// where everyone signed in sees the same front-desk data, and
/// `staff:<id>` on a personal phone. Null when nobody is signed in.
String? readCacheOwnerOf(SessionState session) => switch (session) {
      SignedIn(:final staff) => staff.sharedDevice ? 'desk' : 'staff:${staff.id}',
      _ => null,
    };

/// The screens' reads, from the device first and then the server. Every
/// answer that is worth keeping (see [ApiRead.keep]) is saved, as the server
/// sent it, in the encrypted database.
class ReadCache {
  ReadCache(this._db, this._api, this._owner);

  final AppDatabase _db;
  final StaffApi _api;
  final String? _owner;

  /// What was saved for [read], if anything.
  Future<({T value, DateTime savedAt})?> load<T>(ApiRead<T> read) async {
    final owner = _owner;
    if (!read.keep || owner == null) return null;
    try {
      final row = await (_db.select(_db.cachedReads)
            ..where((r) => r.owner.equals(owner) & r.key.equals(read.key)))
          .getSingleOrNull();
      if (row == null) return null;
      return (value: read.parse(jsonDecode(row.body) as Map<String, dynamic>), savedAt: row.savedAt);
    } catch (_) {
      // Unreadable, or saved by an older version in another shape: fetch it.
      return null;
    }
  }

  /// [read] from the server, saved for next time. Throws AppFailure.
  Future<T> fetch<T>(ApiRead<T> read) async {
    final json = await _api.fetchJson(read);
    final value = read.parse(json);
    final owner = _owner;
    if (read.keep && owner != null) {
      try {
        await _db.into(_db.cachedReads).insertOnConflictUpdate(CachedReadsCompanion.insert(
              owner: owner,
              key: read.key,
              body: jsonEncode(json),
              savedAt: DateTime.now(),
            ));
      } catch (_) {
        // The screen still gets its answer; it just isn't kept.
      }
    }
    return value;
  }
}

final readCacheProvider = Provider<ReadCache>((ref) => ReadCache(
      ref.watch(appDatabaseProvider),
      ref.watch(staffApiProvider),
      ref.watch(sessionControllerProvider.select(readCacheOwnerOf)),
    ));

/// A screen's data, offline first: what was saved on the device shows
/// straight away and the server's answer replaces it when it comes. If the
/// server can't be reached the saved data stays, with an [OutOfDate] error
/// that AsyncView shows as "Offline · updated 10:42". With nothing saved,
/// it waits for the server as before.
class CachedRead<T> extends AsyncNotifier<T> {
  CachedRead(this._read);

  /// The request; may watch other providers (the day picked, say).
  final ApiRead<T> Function(Ref ref) _read;

  @override
  Future<T> build() async {
    final read = _read(ref);
    if (read.keep) ref.cacheFor();
    final cache = ref.watch(readCacheProvider);
    final saved = await cache.load(read);
    if (saved == null) return cache.fetch(read);
    cache.fetch(read).then(
      (fresh) {
        if (ref.mounted) state = AsyncData(fresh);
      },
      onError: (Object e, StackTrace st) {
        if (ref.mounted) state = AsyncError(OutOfDate(e, saved.savedAt), st);
      },
    );
    return saved.value;
  }
}

/// A screen's [CachedRead].
AsyncNotifierProvider<CachedRead<T>, T> cachedRead<T>(ApiRead<T> Function(Ref ref) read) =>
    AsyncNotifierProvider.autoDispose(() => CachedRead(read));

/// A [CachedRead] per argument: a member, a class, a day.
AsyncNotifierProviderFamily<CachedRead<T>, T, A> cachedReadFamily<T, A>(ApiRead<T> Function(Ref ref, A arg) read) =>
    AsyncNotifierProvider.autoDispose.family((A arg) => CachedRead((ref) => read(ref, arg)));
