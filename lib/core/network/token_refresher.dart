import 'package:dio/dio.dart';

import '../../data/models/staff.dart';
import '../storage/session_storage.dart';
import 'auth_interceptor.dart';

/// Exchanges the stored refresh token for new tokens
/// (`POST /staff/token/refresh`) and stores them, with the latest profile:
/// roles changed on the web reach the app here.
class TokenRefresher {
  const TokenRefresher(this._storage, {this.onProfile});

  final SessionStorage _storage;

  /// Told about the refreshed profile, so the open screens follow role changes.
  final void Function(StaffProfile staff)? onProfile;

  Future<RefreshResult> call(Dio dio) async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return const RefreshRejected();
    }
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/staff/token/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {AuthInterceptor.skipUnauthorizedHandler: true}),
      );
      final SignInResult result;
      try {
        result = SignInResult.fromJson(res.data ?? const {});
      } on Object {
        return RefreshUnavailable(DioException.badResponse(
          statusCode: res.statusCode ?? 200,
          requestOptions: res.requestOptions,
          response: res,
        ));
      }
      await _storage.saveSignIn(result);
      onProfile?.call(result.staff);
      return Refreshed(result.token);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // 401: ended, expired or replaced; 422: not a token we can send.
      if (status == 401 || status == 422) return const RefreshRejected();
      return RefreshUnavailable(e);
    }
  }
}
