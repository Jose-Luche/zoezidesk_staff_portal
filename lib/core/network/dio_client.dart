import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/session_controller.dart';
import '../config/env.dart';
import '../storage/session_storage.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';
import 'token_refresher.dart';

Dio buildDio({
  required String baseUrl,
  required AuthInterceptor auth,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  auth.attach(dio);
  dio.interceptors.addAll([auth, RetryInterceptor(dio)]);
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(sessionStorageProvider);
  final dio = buildDio(
    baseUrl: Env.apiBaseUrl,
    auth: AuthInterceptor(
      readToken: storage.readToken,
      // Read lazily: the session controller itself depends on this client.
      refresh: TokenRefresher(
        storage,
        onProfile: (staff) => ref.read(sessionControllerProvider.notifier).updateProfile(staff),
      ).call,
      onUnauthorized: () => ref.read(sessionControllerProvider.notifier).expire(),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
