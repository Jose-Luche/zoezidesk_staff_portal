import 'package:dio/dio.dart';

/// Result of trying to renew an expired access token.
sealed class RefreshResult {
  const RefreshResult();
}

class Refreshed extends RefreshResult {
  const Refreshed(this.token);

  final String token;
}

/// The server refused the refresh token: the member must log in again.
class RefreshRejected extends RefreshResult {
  const RefreshRejected();
}

/// The refresh could not be tried (offline, server error). The session is
/// kept; the request fails with [error].
class RefreshUnavailable extends RefreshResult {
  const RefreshUnavailable(this.error);

  final DioException error;
}

/// Adds the bearer token. When an authenticated request gets a 401 (the
/// access token expired), renews the token once and repeats the request;
/// when renewing is refused, reports it so the session can be ended.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.readToken,
    required this.onUnauthorized,
    this.refresh,
  });

  /// Set in [RequestOptions.extra] to skip the 401 handler, e.g. for logout.
  static const skipUnauthorizedHandler = 'skip_unauthorized_handler';
  static const _retried = 'auth_retried';

  final Future<String?> Function() readToken;
  final void Function() onUnauthorized;

  /// Renews the access token. Without it, any 401 ends the session.
  final Future<RefreshResult> Function(Dio dio)? refresh;

  late final Dio _dio;
  Future<RefreshResult>? _refreshing;

  /// Called by [buildDio]; the client used to refresh and to repeat requests.
  void attach(Dio dio) => _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final sent = options.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        sent == null ||
        options.extra[skipUnauthorizedHandler] == true) {
      return handler.next(err);
    }
    final refresh = this.refresh;
    if (refresh == null || options.extra[_retried] == true) {
      onUnauthorized();
      return handler.next(err);
    }

    // Another request may already have renewed the token.
    final current = await readToken();
    if (current == null || current.isEmpty || 'Bearer $current' == sent) {
      // Requests failing together share one refresh.
      final result = await (_refreshing ??=
          refresh(_dio).whenComplete(() => _refreshing = null));
      switch (result) {
        case Refreshed():
          break;
        case RefreshRejected():
          onUnauthorized();
          return handler.next(err);
        case RefreshUnavailable(:final error):
          return handler.next(error);
      }
    }

    try {
      final response = await _dio.fetch<dynamic>(
        options.copyWith(extra: {...options.extra, _retried: true}),
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
