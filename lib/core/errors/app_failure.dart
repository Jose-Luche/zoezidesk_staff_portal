import 'dart:io';

import 'package:dio/dio.dart';

/// Every error that reaches state or UI is one of these. Screens switch on
/// the type to pick a designed state; [message] is safe to show as-is.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No connection or DNS failure: the phone is offline. Screens show their
/// offline state and cached data.
class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'You appear to be offline. Check your connection and try again.',
  ]);
}

/// Connected, but the server did not answer in time. Not "offline": the
/// member should simply try again.
class TimeoutFailure extends AppFailure {
  const TimeoutFailure([
    super.message = 'The server is taking too long to respond. Please try again.',
  ]);
}

class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Your session has ended. Please log in again.',
  ]);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  final Map<String, String> fieldErrors;
}

class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure(super.message, {this.retryAfter});

  final Duration? retryAfter;
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;
}

const _genericMessage = 'Something went wrong. Please try again.';

/// Converts a dio error into an [AppFailure], reading Laravel's
/// `{message, errors}` body when there is one.
AppFailure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
      // Could not connect at all.
      return const NetworkFailure();
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.unknown:
      // SocketException surfaces here on some platforms.
      return e.error is SocketException
          ? const NetworkFailure()
          : const ServerFailure(_genericMessage);
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
      return const ServerFailure(_genericMessage);
  }
}

AppFailure _fromResponse(Response<dynamic>? response) {
  final status = response?.statusCode;
  final body = response?.data;
  final json = body is Map ? body.cast<String, dynamic>() : const <String, dynamic>{};
  final serverMessage = json['message'] is String ? json['message'] as String : null;

  switch (status) {
    case 401:
      return const UnauthorizedFailure();
    case 422:
      final errors = <String, String>{};
      final raw = json['errors'];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is List && value.isNotEmpty) errors['$key'] = '${value.first}';
        });
      }
      return ValidationFailure(
        errors.values.firstOrNull ?? serverMessage ?? _genericMessage,
        fieldErrors: errors,
      );
    case 429:
      final seconds = json['retry_after'];
      return RateLimitedFailure(
        serverMessage ?? 'Too many attempts. Please wait a few minutes.',
        retryAfter: seconds is int ? Duration(seconds: seconds) : null,
      );
    default:
      return ServerFailure(
        status != null && status < 500 && serverMessage != null
            ? serverMessage
            : _genericMessage,
        statusCode: status,
      );
  }
}

/// Runs [request] and rethrows dio and parsing errors as [AppFailure].
Future<T> guardRequest<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e) {
    throw mapDioException(e);
  } on TypeError {
    // Response body did not match the expected shape.
    throw const ServerFailure(_genericMessage);
  } on FormatException {
    throw const ServerFailure(_genericMessage);
  }
}
