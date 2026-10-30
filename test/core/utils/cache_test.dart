import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/errors/app_failure.dart';
import 'package:zoezidesk_staff/core/network/dio_client.dart';
import 'package:zoezidesk_staff/core/theme/app_theme.dart';
import 'package:zoezidesk_staff/core/storage/session_storage.dart';
import 'package:zoezidesk_staff/core/utils/cache.dart';
import 'package:zoezidesk_staff/data/repositories/read_cache.dart';
import 'package:zoezidesk_staff/data/models/staff.dart';
import 'package:zoezidesk_staff/features/auth/state/session_controller.dart';
import 'package:zoezidesk_staff/shared/widgets/async_view.dart';

import '../../helpers/fakes.dart';

void main() {
  late int fetches;
  late ProviderContainer container;

  FutureProvider<int> cached({Duration fresh = const Duration(minutes: 1)}) => FutureProvider.autoDispose<int>((ref) {
        ref.cacheFor(fresh: fresh);
        return Future.value(++fetches);
      });

  setUp(() {
    fetches = 0;
    container = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(InMemorySecureStore())]);
    addTearDown(container.dispose);
  });

  Future<AsyncValue<int>> showAgain(FutureProvider<int> provider) async {
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    return sub.read();
  }

  test('going back to a screen shows the last value without fetching again', () async {
    final provider = cached();
    final sub = container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), 1);
    sub.close();
    await container.pump();

    expect((await showAgain(provider)).value, 1);
    expect(fetches, 1);
  });

  test('an old value stays on screen while it is fetched again', () async {
    final provider = cached(fresh: Duration.zero);
    final sub = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    sub.close();
    await container.pump();
    await Future<void>.delayed(const Duration(milliseconds: 2));

    final shown = await showAgain(provider);
    expect(shown.value, 1);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(provider.future), 2);
  });

  test('the next person to sign in never sees the last one\'s data', () async {
    final session = container.read(sessionControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero); // the stored session: nobody
    session.signedIn(staffWith(receptionistPermissions));
    final provider = cached();
    final sub = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    sub.close();
    await container.pump();

    // Locked, and the next person signs in with their PIN.
    session.enrolled(const FrontDeskDevice(id: 3, name: 'Front desk', gymName: 'Test Gym'));
    session.signedIn(staffWith(receptionistPermissions, shared: true));
    await container.pump();

    final shown = await showAgain(provider);
    expect(shown.hasValue, isFalse);
    expect(await container.read(provider.future), 2);
  });

  group('AsyncView', () {
    Widget view(AsyncValue<String> value) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(children: [
              AsyncView(value: value, onRetry: () {}, data: (s) => Text(s)),
            ]),
          ),
        );

    /// 'Amina', then a refresh that fails with [error].
    Future<AsyncValue<String>> refreshFailed(WidgetTester tester, Object error) async {
      var calls = 0;
      final provider = FutureProvider<String>((_) => ++calls == 1 ? 'Amina' : throw error);
      final c = ProviderContainer(retry: (_, _) => null);
      addTearDown(c.dispose);
      await c.read(provider.future);
      await tester.runAsync(() => c.refresh(provider.future).catchError((_) => ''));
      return c.read(provider);
    }

    testWidgets('a failed refresh keeps the data, with a note', (tester) async {
      await tester.pumpWidget(view(await refreshFailed(tester, const NetworkFailure())));
      expect(find.text('Amina'), findsOneWidget);
      expect(find.text('Offline · showing what was loaded earlier'), findsOneWidget);
    });

    testWidgets('saved data says when it was saved', (tester) async {
      final saved = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(view(await refreshFailed(tester, OutOfDate(const NetworkFailure(), saved))));
      expect(find.text('Amina'), findsOneWidget);
      expect(find.text('Offline · updated 5 min ago'), findsOneWidget);
    });

    testWidgets('saved data more than a day old is called out', (tester) async {
      final saved = DateTime.now().subtract(const Duration(days: 3));
      await tester.pumpWidget(view(await refreshFailed(tester, OutOfDate(const NetworkFailure(), saved))));
      expect(find.textContaining('may be out of date'), findsOneWidget);
    });

    testWidgets('a first load that fails shows offline', (tester) async {
      await tester.pumpWidget(view(const AsyncError<String>(NetworkFailure(), StackTrace.empty)));
      expect(find.text('You are offline'), findsOneWidget);
    });
  });

  test('reads give up connecting sooner than writes', () {
    final get = RequestOptions(path: '/x', method: 'GET', connectTimeout: const Duration(seconds: 15));
    final post = RequestOptions(path: '/x', method: 'POST', connectTimeout: const Duration(seconds: 15));
    const ReadTimeoutInterceptor()
      ..onRequest(get, RequestInterceptorHandler())
      ..onRequest(post, RequestInterceptorHandler());
    expect(get.connectTimeout, const Duration(seconds: 5));
    expect(post.connectTimeout, const Duration(seconds: 15));
  });
}
