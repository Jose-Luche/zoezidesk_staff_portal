import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';

/// Phones that receive notifications (`/staff/push-devices`).
class PushDevicesApi {
  const PushDevicesApi(this._dio);

  final Dio _dio;

  /// Registering the same token again only refreshes it.
  Future<void> register(String token) => _dio.put<void>(
        '/staff/push-devices',
        data: {'token': token, 'platform': 'android'},
      );

  Future<void> unregister(String token) =>
      _dio.delete<void>('/staff/push-devices', data: {'token': token});
}

final pushDevicesApiProvider = Provider<PushDevicesApi>((ref) => PushDevicesApi(ref.watch(dioProvider)));
