import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/storage/session_storage.dart';
import '../api/staff_api.dart';
import '../models/staff.dart';

/// What the app knows at startup.
class StoredSession {
  const StoredSession({this.staff, this.device});

  final StaffProfile? staff;
  final FrontDeskDevice? device;
}

class AuthRepository {
  const AuthRepository({required this.api, required this.storage, this.deviceName = 'ZoeziDesk Staff Android'});

  final StaffApi api;
  final SessionStorage storage;
  final String deviceName;

  /// Email and password on a staff member's own phone. Throws [AppFailure].
  Future<StaffProfile> login({required String email, required String password}) async {
    final result = await api.login(email: email, password: password, deviceName: deviceName);
    await storage.saveSignIn(result);
    return result.staff;
  }

  /// Makes this phone or tablet the gym's front-desk device. Throws [AppFailure].
  Future<FrontDeskDevice> enrol({required String code, required String name}) async {
    final enrolled = await api.enrolDevice(code: code.trim(), name: name.trim());
    await storage.saveDevice(enrolled.token, enrolled.device);
    return enrolled.device;
  }

  /// Staff who can sign in on this device. Throws [AppFailure];
  /// [UnauthorizedFailure] means the device was revoked on the web.
  Future<List<LockScreenStaff>> lockScreenStaff() async {
    final token = await storage.readDeviceToken();
    if (token == null) throw const UnauthorizedFailure();
    return api.deviceStaff(token);
  }

  Future<StaffProfile> pinLogin({required int staffId, required String pin}) async {
    final token = await storage.readDeviceToken();
    if (token == null) throw const UnauthorizedFailure();
    final result = await api.pinLogin(deviceToken: token, staffId: staffId, pin: pin);
    await storage.saveSignIn(result);
    return result.staff;
  }

  /// The stored sign-in and device. Unreadable storage starts fresh.
  Future<StoredSession> restore() async {
    try {
      final device = await storage.readDevice();
      final token = await storage.readToken();
      final staff = token == null || token.isEmpty ? null : await storage.readStaff();
      return StoredSession(staff: staff, device: device);
    } catch (_) {
      // Corrupt secure storage (e.g. after a device restore).
      await storage.clearSession();
      return const StoredSession();
    }
  }

  /// The latest profile from the server, saved. Throws [AppFailure].
  Future<StaffProfile> refreshProfile() async {
    final staff = await api.me();
    await storage.saveStaff(staff);
    return staff;
  }

  /// Best-effort server sign-out, then always clear the session (the device
  /// stays enrolled). Offline, the server session lapses on its own.
  Future<void> signOut() async {
    try {
      final refresh = await storage.readRefreshToken();
      if (refresh != null) await api.revoke(refresh).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Signing out must work offline.
    }
    await storage.clearSession();
  }

  /// Local only, for when the server has already ended the session.
  Future<void> discardSession() => storage.clearSession();

  Future<void> forgetDevice() => storage.forgetDevice();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(api: ref.watch(staffApiProvider), storage: ref.watch(sessionStorageProvider)),
);
