import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/retry_interceptor.dart';
import '../models/members.dart';
import '../models/staff.dart';
import '../models/work.dart';

/// Registering a member: saved, or the server found possible duplicates.
sealed class RegisterResult {
  const RegisterResult();
}

class Registered extends RegisterResult {
  const Registered(this.member);

  final MemberCard member;
}

class PossibleDuplicates extends RegisterResult {
  const PossibleDuplicates(this.duplicates);

  final List<PossibleDuplicate> duplicates;
}

/// `/api/staff`, documented in the backend's STAFF_APP_API.md. Every method
/// throws [AppFailure].
class StaffApi {
  const StaffApi(this._dio);

  final Dio _dio;

  static const _uuid = Uuid();

  /// A fresh key per user action. Reused by RetryInterceptor on retries, so
  /// a payment on a weak connection is never taken twice.
  static Options _once() => Options(headers: {RetryInterceptor.idempotencyHeader: _uuid.v4()});

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) => guardRequest(() async {
        final res = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
        return res.data!;
      });

  // ── Signing in ────────────────────────────────────────────────────

  Future<SignInResult> login({required String email, required String password, required String deviceName}) =>
      guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/login',
            data: {'email': email, 'password': password, 'device_name': deviceName});
        return SignInResult.fromJson(res.data!);
      });

  Future<StaffProfile> me() async => StaffProfile.fromJson((await _get('/staff/me'))['staff'] as Map<String, dynamic>);

  /// Ends the session on the server; works after the access token expired.
  /// A 401 means it is already gone, so it must not end the session again.
  Future<void> revoke(String refreshToken) => _dio.post<void>(
        '/staff/token/revoke',
        data: {'refresh_token': refreshToken},
        options: Options(
          extra: {AuthInterceptor.skipUnauthorizedHandler: true},
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

  Future<void> setPin({required String password, required String pin}) => guardRequest(() =>
      _dio.put<void>('/staff/me/pin', data: {'password': password, 'pin': pin, 'pin_confirmation': pin}));

  // ── Front-desk device ─────────────────────────────────────────────

  Future<({String token, FrontDeskDevice device})> enrolDevice({required String code, required String name}) =>
      guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/devices/enrol', data: {'code': code, 'name': name});
        return (
          token: res.data!['device_token'] as String,
          device: FrontDeskDevice.fromJson(res.data!['device'] as Map<String, dynamic>),
        );
      });

  Future<List<LockScreenStaff>> deviceStaff(String deviceToken) => guardRequest(() async {
        final res = await _dio.get<Map<String, dynamic>>('/staff/devices/staff',
            options: Options(
              headers: {'X-Device-Token': deviceToken},
              extra: {AuthInterceptor.skipUnauthorizedHandler: true},
            ));
        return [for (final s in res.data!['staff'] as List) LockScreenStaff.fromJson(s as Map<String, dynamic>)];
      });

  Future<SignInResult> pinLogin({required String deviceToken, required int staffId, required String pin}) =>
      guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/devices/pin-login',
            data: {'staff_id': staffId, 'pin': pin},
            options: Options(
              headers: {'X-Device-Token': deviceToken},
              extra: {AuthInterceptor.skipUnauthorizedHandler: true},
            ));
        return SignInResult.fromJson(res.data!);
      });

  // ── Front desk ────────────────────────────────────────────────────

  /// A refused check-in (expired, suspended, unknown code) is a result, not an error.
  Future<CheckInResult> checkIn({String? qrCode, int? memberId}) => guardRequest(() async {
        final options = _once().copyWith(validateStatus: (s) => s != null && (s < 300 || s == 422));
        final res = await _dio.post<Map<String, dynamic>>('/staff/checkins',
            data: {'qr_code': ?qrCode, 'member_id': ?memberId}, options: options);
        if (res.statusCode == 422 && res.data?['member'] == null && res.data?['errors'] != null) {
          throw ValidationFailure(res.data!['message'] as String? ?? 'Check the details and try again.');
        }
        return CheckInResult.fromJson(res.data!);
      });

  Future<({int count, List<TodayCheckIn> checkIns})> todayCheckIns() async {
    final json = await _get('/staff/checkins/today');
    return (
      count: json['count'] as int,
      checkIns: [for (final c in json['checkins'] as List) TodayCheckIn.fromJson(c as Map<String, dynamic>)],
    );
  }

  Future<List<MemberCard>> lookup(String query) async {
    final json = await _get('/staff/members/lookup', {'q': query});
    return [for (final m in json['members'] as List) MemberCard.fromJson(m as Map<String, dynamic>)];
  }

  Future<MemberCard> card(int memberId) async =>
      MemberCard.fromJson((await _get('/staff/members/$memberId/card'))['member'] as Map<String, dynamic>);

  // ── Members ───────────────────────────────────────────────────────

  Future<({List<MemberCard> members, bool onlyAssigned, int lastPage})> members({String? search, int page = 1}) async {
    final json = await _get('/staff/members', {'search': ?search, 'page': page});
    return (
      members: [for (final m in json['members'] as List) MemberCard.fromJson(m as Map<String, dynamic>)],
      onlyAssigned: json['only_assigned'] as bool? ?? false,
      lastPage: (json['meta'] as Map)['last_page'] as int,
    );
  }

  Future<MemberProfile> member(int id) async => MemberProfile.fromJson(await _get('/staff/members/$id'));

  Future<RegisterResult> register(Map<String, dynamic> fields, {bool confirmDuplicate = false}) => guardRequest(() async {
        final options = _once().copyWith(validateStatus: (s) => s != null && (s < 300 || s == 409));
        final res = await _dio.post<Map<String, dynamic>>('/staff/members',
            data: {...fields, if (confirmDuplicate) 'confirm_duplicate': true}, options: options);
        if (res.statusCode == 409) {
          return PossibleDuplicates([
            for (final d in res.data!['duplicates'] as List) PossibleDuplicate.fromJson(d as Map<String, dynamic>),
          ]);
        }
        return Registered(MemberCard.fromJson(res.data!['member'] as Map<String, dynamic>));
      });

  Future<MemberCard> updateMember(int id, Map<String, dynamic> fields) => guardRequest(() async {
        final res = await _dio.patch<Map<String, dynamic>>('/staff/members/$id', data: fields);
        return MemberCard.fromJson(res.data!['member'] as Map<String, dynamic>);
      });

  /// Who to call: memberships ending within [days], and ones that ended in
  /// the last [lapsedDays] without a renewal.
  Future<({List<FollowUp> expiring, List<FollowUp> lapsed})> followUps({int days = 7, int lapsedDays = 14}) async {
    final json = await _get('/staff/members/expiring', {'days': days, 'lapsed_days': lapsedDays});
    List<FollowUp> rows(String key) => [for (final r in json[key] as List) FollowUp.fromJson(r as Map<String, dynamic>)];
    return (expiring: rows('expiring'), lapsed: rows('lapsed'));
  }

  // ── Payments ──────────────────────────────────────────────────────

  Future<Plans> plans() async {
    final json = await _get('/staff/plans');
    return Plans(
      mpesaEnabled: json['mpesa_enabled'] as bool? ?? false,
      plans: [for (final p in json['plans'] as List) Plan.fromJson(p as Map<String, dynamic>)],
    );
  }

  Future<PaymentRecord> payCash({
    required int memberId,
    required int planId,
    required int amount,
    required String method,
    String? reference,
    bool notify = true,
  }) =>
      guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/payments/cash',
            data: {
              'member_id': memberId,
              'plan_id': planId,
              'amount': amount,
              'method': method,
              'reference': ?reference,
              'notify': notify,
            },
            options: _once());
        return PaymentRecord.fromJson(res.data!['payment'] as Map<String, dynamic>);
      });

  Future<PaymentRecord> requestMpesa({required int memberId, required int planId, required String phone}) =>
      guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/payments/mpesa',
            data: {'member_id': memberId, 'plan_id': planId, 'phone': phone}, options: _once());
        return PaymentRecord.fromJson(res.data!['payment'] as Map<String, dynamic>);
      });

  Future<({PaymentRecord payment, String? failureReason})> payment(int id) async {
    final json = await _get('/staff/payments/$id');
    return (
      payment: PaymentRecord.fromJson(json['payment'] as Map<String, dynamic>),
      failureReason: json['failure_reason'] as String?,
    );
  }

  /// A signed link to the PDF receipt, valid for a week without signing in.
  Future<String> receiptLink(int paymentId) => guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/payments/$paymentId/receipt-link');
        return res.data!['url'] as String;
      });

  /// Owners and managers: voids a completed payment.
  Future<PaymentRecord> voidPayment(int paymentId, String reason) => guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/payments/$paymentId/void', data: {'reason': reason});
        return PaymentRecord.fromJson(res.data!['payment'] as Map<String, dynamic>);
      });

  Future<Shift> shift({DateTime? date, int? staffId}) async => Shift.fromJson(await _get('/staff/payments/shift', {
        if (date != null) 'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'staff_id': ?staffId,
      }));

  // ── Classes ───────────────────────────────────────────────────────

  Future<List<ClassItem>> classes(DateTime day) async {
    final json = await _get('/staff/classes', {
      'date': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
    });
    return [for (final c in json['classes'] as List) ClassItem.fromJson(c as Map<String, dynamic>)];
  }

  Future<List<({MemberCard member, String status})>> roster(int classId) async {
    final json = await _get('/staff/classes/$classId/roster');
    return [
      for (final b in (json['bookings'] as List).cast<Map<String, dynamic>>())
        (member: MemberCard.fromJson(b['member'] as Map<String, dynamic>), status: b['status'] as String),
    ];
  }

  /// Books a member into a class. Returns the server's message (e.g. already booked).
  Future<String> bookClass(int classId, int memberId) => guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/classes/$classId/bookings',
            data: {'member_id': memberId}, options: _once());
        return res.data!['message'] as String? ?? 'Booked.';
      });

  Future<void> cancelBooking(int classId, int memberId) =>
      guardRequest(() => _dio.delete<void>('/staff/classes/$classId/bookings/$memberId'));

  Future<void> setAttended(int classId, int memberId, {required bool attended}) => guardRequest(
      () => _dio.put<void>('/staff/classes/$classId/bookings/$memberId/attended', data: {'attended': attended}));

  // ── Trainers ──────────────────────────────────────────────────────

  Future<TrainerDashboard> trainerDashboard() async => TrainerDashboard.fromJson(await _get('/staff/trainer/dashboard'));

  Future<TrainingSummary?> training(int memberId) async {
    final t = (await _get('/staff/members/$memberId/training'))['training'];
    return t == null ? null : TrainingSummary.fromJson(t as Map<String, dynamic>);
  }

  Future<List<TrainerNote>> notes(int memberId) async {
    final json = await _get('/staff/members/$memberId/notes');
    return [for (final n in json['notes'] as List) TrainerNote.fromJson(n as Map<String, dynamic>)];
  }

  Future<void> addNote(int memberId, {required String type, required String note, required DateTime sessionDate}) =>
      guardRequest(() => _dio.post<void>('/staff/members/$memberId/notes',
          data: {
            'type': type,
            'note': note,
            'session_date':
                '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
          },
          options: _once()));

  Future<void> deleteNote(int noteId) => guardRequest(() => _dio.delete<void>('/staff/notes/$noteId'));

  // ── Owners and managers ───────────────────────────────────────────

  Future<TodayReport> todayReport() async => TodayReport.fromJson(await _get('/staff/reports/today'));

  Future<PeriodReport> periodReport(String period) async =>
      PeriodReport.fromJson(await _get('/staff/reports/summary', {'period': period}));
}

final staffApiProvider = Provider<StaffApi>((ref) => StaffApi(ref.watch(dioProvider)));
