import 'dart:math';

import 'package:dio/dio.dart';

/// Retries transient failures (timeouts, connection errors, 502/503/504)
/// with exponential backoff and jitter. Only safe requests are retried:
/// GET/HEAD, or writes that carry an `Idempotency-Key` header.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    Random? random,
    Future<void> Function(Duration)? sleep,
  })  : _random = random ?? Random(),
        _sleep = sleep ?? Future<void>.delayed;

  static const idempotencyHeader = 'Idempotency-Key';
  static const _attemptKey = 'retry_attempt';

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Random _random;
  final Future<void> Function(Duration) _sleep;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;

    if (attempt >= maxRetries || !_isTransient(err) || !_isSafe(options)) {
      handler.next(err);
      return;
    }

    await _sleep(delayFor(attempt));
    options.extra[_attemptKey] = attempt + 1;

    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// 500ms, 1s, 2s … plus up to [baseDelay] of jitter.
  Duration delayFor(int attempt) {
    final backoff = baseDelay * pow(2, attempt).toInt();
    final jitter = baseDelay * _random.nextDouble();
    return backoff + jitter;
  }

  static bool _isTransient(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        DioExceptionType.badResponse =>
          const {502, 503, 504}.contains(e.response?.statusCode),
        _ => false,
      };

  static bool _isSafe(RequestOptions o) {
    final method = o.method.toUpperCase();
    return method == 'GET' ||
        method == 'HEAD' ||
        o.headers.containsKey(idempotencyHeader);
  }
}
