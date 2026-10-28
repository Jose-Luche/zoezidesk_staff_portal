import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/staff.dart';

/// Minimal key-value contract so tests can use an in-memory store.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Tokens, the signed-in staff member and the front-desk device credential
/// live only in secure storage. Signing out clears the session but keeps
/// the device enrolled: the next person signs in with their PIN.
class SessionStorage {
  const SessionStorage(this._store);

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _staffKey = 'auth_staff';
  static const _deviceTokenKey = 'device_token';
  static const _deviceKey = 'device';

  final SecureStore _store;

  Future<String?> readToken() => _store.read(_tokenKey);

  Future<String?> readRefreshToken() => _store.read(_refreshTokenKey);

  Future<StaffProfile?> readStaff() async {
    final raw = await _store.read(_staffKey);
    return raw == null ? null : StaffProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSignIn(SignInResult result) async {
    await saveTokens(token: result.token, refreshToken: result.refreshToken);
    await saveStaff(result.staff);
  }

  /// The refresh token is written first: if writing the access token then
  /// fails, the next 401 simply refreshes again.
  Future<void> saveTokens({required String token, String? refreshToken}) async {
    if (refreshToken != null) await _store.write(_refreshTokenKey, refreshToken);
    await _store.write(_tokenKey, token);
  }

  Future<void> saveStaff(StaffProfile staff) => _store.write(_staffKey, jsonEncode(staff.toJson()));

  Future<void> clearSession() async {
    for (final key in [_tokenKey, _refreshTokenKey, _staffKey]) {
      await _store.delete(key);
    }
  }

  // ── Front-desk device ─────────────────────────────────────────────

  Future<String?> readDeviceToken() => _store.read(_deviceTokenKey);

  Future<FrontDeskDevice?> readDevice() async {
    final raw = await _store.read(_deviceKey);
    return raw == null ? null : FrontDeskDevice.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveDevice(String token, FrontDeskDevice device) async {
    await _store.write(_deviceTokenKey, token);
    await _store.write(_deviceKey, jsonEncode(device.toJson()));
  }

  Future<void> forgetDevice() async {
    await _store.delete(_deviceTokenKey);
    await _store.delete(_deviceKey);
  }
}

final secureStoreProvider = Provider<SecureStore>((_) => const FlutterSecureStore());

final sessionStorageProvider =
    Provider<SessionStorage>((ref) => SessionStorage(ref.watch(secureStoreProvider)));
