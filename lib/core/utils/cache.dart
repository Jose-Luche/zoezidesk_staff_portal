import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/session_controller.dart';

/// Whose data the cached providers hold: the signed-in staff member's id,
/// null when nobody is. On the front-desk device this changes with every
/// PIN sign-in.
int? cacheOwnerOf(SessionState session) => switch (session) {
      SignedIn(:final staff) => staff.id,
      _ => null,
    };

final cacheOwnerProvider = Provider<int?>((ref) => cacheOwnerOf(ref.watch(sessionControllerProvider)));

/// Every provider using [CacheFor], so they can all be dropped at once. The
/// session controller does that whenever the signed-in person changes; a
/// cached provider can't watch for it itself, as one that isn't on screen
/// is paused and would only hear of it when shown again.
class SessionCache {
  final _drops = <void Function()>{};

  /// Drops every cached value; nothing of the last person's is shown again.
  void clear() {
    for (final drop in [..._drops]) {
      drop();
    }
  }
}

final sessionCacheProvider = Provider<SessionCache>((_) => SessionCache());

extension CacheFor on Ref {
  /// Keeps an autoDispose provider's last value after its screen closes or
  /// its tab is hidden, so going back shows it straight away. When it is
  /// shown again and is older than [fresh], it is fetched again in the
  /// background while the old value stays on screen. Dropped [keep] after
  /// the last screen let go, or as soon as the signed-in person changes.
  void cacheFor({Duration fresh = const Duration(minutes: 1), Duration keep = const Duration(minutes: 30)}) {
    final link = keepAlive();
    final fetchedAt = DateTime.now();
    final cache = read(sessionCacheProvider);
    Timer? timer;
    void drop() {
      link.close();
      // Cleared rather than refreshed, in case a screen still shows it.
      invalidateSelf(asReload: true);
    }

    cache._drops.add(drop);
    onCancel(() {
      timer?.cancel();
      timer = Timer(keep, link.close);
    });
    onResume(() {
      timer?.cancel();
      if (DateTime.now().difference(fetchedAt) <= fresh) return;
      // Not while the widget that resumed it is still building.
      Future.microtask(() {
        if (mounted) invalidateSelf();
      });
    });
    onDispose(() {
      timer?.cancel();
      cache._drops.remove(drop);
    });
  }
}
