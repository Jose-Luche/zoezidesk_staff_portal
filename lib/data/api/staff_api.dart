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

/// Recording an enquiry: saved, or the phone already belongs to someone.
sealed class EnquiryResult {
  const EnquiryResult(this.message);

  final String message;
}

class EnquiryRecorded extends EnquiryResult {
  const EnquiryRecorded(this.enquiry, {required this.welcomeSent}) : super('');

  final Enquiry enquiry;
  final bool welcomeSent;
}

class AlreadyAMember extends EnquiryResult {
  const AlreadyAMember(super.message, this.memberId);

  final int memberId;
}

class AlreadyEnquired extends EnquiryResult {
  const AlreadyEnquired(super.message, this.enquiry);

  final Enquiry enquiry;
}

/// A GET the app can keep for offline: the request, and how to read its
/// answer. The answer is cached as the server sent it and read back with
/// [parse], the same as a live one.
class ApiRead<T> {
  const ApiRead(this.path, this.parse, {this.query = const {}, this.keep = true});

  final String path;
  final Map<String, dynamic> query;
  final T Function(Map<String, dynamic> json) parse;

  /// False for answers that aren't worth keeping, like a search as it is typed.
  final bool keep;

  /// The path and query, in a fixed order.
  String get key {
    final names = query.keys.toList()..sort();
    return names.isEmpty ? path : '$path?${[for (final n in names) '$n=${query[n]}'].join('&')}';
  }
}

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The screens' reads, cached for offline by ReadCache.
abstract final class StaffReads {
  static const todayCheckIns = ApiRead('/staff/checkins/today', _todayCheckIns);

  static ({int count, List<TodayCheckIn> checkIns}) _todayCheckIns(Map<String, dynamic> json) => (
        count: json['count'] as int,
        checkIns: [for (final c in json['checkins'] as List) TodayCheckIn.fromJson(c as Map<String, dynamic>)],
      );

  /// Only the full list is kept; searches are typed live.
  static ApiRead<({List<MemberCard> members, bool onlyAssigned, int lastPage})> members({String? search, int page = 1}) =>
      ApiRead('/staff/members', _members, query: {'search': ?search, 'page': page}, keep: search == null);

  static ({List<MemberCard> members, bool onlyAssigned, int lastPage}) _members(Map<String, dynamic> json) => (
        members: [for (final m in json['members'] as List) MemberCard.fromJson(m as Map<String, dynamic>)],
        onlyAssigned: json['only_assigned'] as bool? ?? false,
        lastPage: (json['meta'] as Map)['last_page'] as int,
      );

  static ApiRead<MemberProfile> member(int id) => ApiRead('/staff/members/$id', MemberProfile.fromJson);

  static const followUps = ApiRead('/staff/members/expiring', _followUps, query: {'days': 7, 'lapsed_days': 14});

  static ({List<FollowUp> expiring, List<FollowUp> lapsed}) _followUps(Map<String, dynamic> json) {
    List<FollowUp> rows(String key) => [for (final r in json[key] as List) FollowUp.fromJson(r as Map<String, dynamic>)];
    return (expiring: rows('expiring'), lapsed: rows('lapsed'));
  }

  static ApiRead<Shift> shift({DateTime? date, int? staffId}) => ApiRead(
        '/staff/payments/shift',
        Shift.fromJson,
        query: {if (date != null) 'date': _day(date), 'staff_id': ?staffId},
      );

  static const enquiries = ApiRead('/staff/leads', _enquiries);

  static List<Enquiry> _enquiries(Map<String, dynamic> json) =>
      [for (final l in json['leads'] as List) Enquiry.fromJson(l as Map<String, dynamic>)];

  static ApiRead<List<ClassItem>> classes(DateTime day) =>
      ApiRead('/staff/classes', _classes, query: {'date': _day(day)});

  static List<ClassItem> _classes(Map<String, dynamic> json) =>
      [for (final c in json['classes'] as List) ClassItem.fromJson(c as Map<String, dynamic>)];

  static ApiRead<List<({MemberCard member, String status})>> roster(int classId) =>
      ApiRead('/staff/classes/$classId/roster', _roster);

  static List<({MemberCard member, String status})> _roster(Map<String, dynamic> json) => [
        for (final b in (json['bookings'] as List).cast<Map<String, dynamic>>())
          (member: MemberCard.fromJson(b['member'] as Map<String, dynamic>), status: b['status'] as String),
      ];

  static const trainerDashboard = ApiRead('/staff/trainer/dashboard', TrainerDashboard.fromJson);

  static ApiRead<TrainingSummary?> training(int memberId) => ApiRead('/staff/members/$memberId/training', _training);

  static TrainingSummary? _training(Map<String, dynamic> json) {
    final t = json['training'];
    return t == null ? null : TrainingSummary.fromJson(t as Map<String, dynamic>);
  }

  static ApiRead<List<TrainerNote>> notes(int memberId) => ApiRead('/staff/members/$memberId/notes', _notes);

  static List<TrainerNote> _notes(Map<String, dynamic> json) =>
      [for (final n in json['notes'] as List) TrainerNote.fromJson(n as Map<String, dynamic>)];

  static const todayReport = ApiRead('/staff/reports/today', TodayReport.fromJson);

  static ApiRead<PeriodReport> periodReport(String period) =>
      ApiRead('/staff/reports/summary', PeriodReport.fromJson, query: {'period': period});
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

  /// The answer to [read] as the server sent it, for the offline cache.
  Future<Map<String, dynamic>> fetchJson(ApiRead<Object?> read) => _get(read.path, read.query);

  Future<T> fetch<T>(ApiRead<T> read) async => read.parse(await fetchJson(read));

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
  /// [at] and [idempotencyKey] are for check-ins recorded offline and sent
  /// later: when the member came, and the key kept with the queued entry.
  Future<CheckInResult> checkIn({String? qrCode, int? memberId, DateTime? at, String? idempotencyKey}) =>
      guardRequest(() async {
        final options = Options(headers: {RetryInterceptor.idempotencyHeader: idempotencyKey ?? _uuid.v4()})
            .copyWith(validateStatus: (s) => s != null && (s < 300 || s == 422));
        final res = await _dio.post<Map<String, dynamic>>('/staff/checkins',
            data: {'qr_code': ?qrCode, 'member_id': ?memberId, 'checked_in_at': ?at?.toUtc().toIso8601String()},
            options: options);
        if (res.statusCode == 422 && res.data?['member'] == null && res.data?['errors'] != null) {
          throw ValidationFailure(res.data!['message'] as String? ?? 'Check the details and try again.');
        }
        return CheckInResult.fromJson(res.data!);
      });

  /// Members with a current membership, each with the sha256 of their QR
  /// code: what the desk checks scans against with no connection.
  Future<List<OfflineMember>> offlineList() async {
    final json = await _get('/staff/checkins/offline-list');
    return [for (final m in json['members'] as List) OfflineMember.fromJson(m as Map<String, dynamic>)];
  }

  Future<({int count, List<TodayCheckIn> checkIns})> todayCheckIns() => fetch(StaffReads.todayCheckIns);

  Future<List<MemberCard>> lookup(String query) async {
    final json = await _get('/staff/members/lookup', {'q': query});
    return [for (final m in json['members'] as List) MemberCard.fromJson(m as Map<String, dynamic>)];
  }

  Future<MemberCard> card(int memberId) async =>
      MemberCard.fromJson((await _get('/staff/members/$memberId/card'))['member'] as Map<String, dynamic>);

  // ── Members ───────────────────────────────────────────────────────

  Future<({List<MemberCard> members, bool onlyAssigned, int lastPage})> members({String? search, int page = 1}) =>
      fetch(StaffReads.members(search: search, page: page));

  Future<MemberProfile> member(int id) => fetch(StaffReads.member(id));

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

  /// A photo taken at the desk (a JPEG file on the phone); replaces the old one.
  Future<MemberCard> uploadMemberPhoto(int id, String filePath) => guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/members/$id/photo',
            data: FormData.fromMap({'photo': await MultipartFile.fromFile(filePath, filename: 'photo.jpg')}));
        return MemberCard.fromJson(res.data!['member'] as Map<String, dynamic>);
      });

  Future<MemberCard> removeMemberPhoto(int id) => guardRequest(() async {
        final res = await _dio.delete<Map<String, dynamic>>('/staff/members/$id/photo');
        return MemberCard.fromJson(res.data!['member'] as Map<String, dynamic>);
      });

  /// Who to call: memberships ending within [days], and ones that ended in
  /// the last [lapsedDays] without a renewal.
  Future<({List<FollowUp> expiring, List<FollowUp> lapsed})> followUps() => fetch(StaffReads.followUps);

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

  Future<Shift> shift({DateTime? date, int? staffId}) => fetch(StaffReads.shift(date: date, staffId: staffId));

  // ── Walk-in enquiries ─────────────────────────────────────────────

  Future<List<Enquiry>> enquiries() => fetch(StaffReads.enquiries);

  Future<EnquiryResult> recordEnquiry(Map<String, dynamic> fields, {bool confirm = false}) => guardRequest(() async {
        final options = _once().copyWith(validateStatus: (s) => s != null && (s < 300 || s == 409));
        final res = await _dio.post<Map<String, dynamic>>('/staff/leads',
            data: {...fields, if (confirm) 'confirm': true}, options: options);
        final json = res.data!;
        return switch ((res.statusCode, json['code'])) {
          (409, 'already_member') => AlreadyAMember(json['message'] as String, json['member_id'] as int),
          (409, _) => AlreadyEnquired(json['message'] as String, Enquiry.fromJson(json['lead'] as Map<String, dynamic>)),
          _ => EnquiryRecorded(Enquiry.fromJson(json['lead'] as Map<String, dynamic>),
              welcomeSent: json['welcome_sent'] as bool? ?? false),
        };
      });

  /// [outcome]: contacted, interested or lost.
  Future<Enquiry> followUpEnquiry(int id, {required String outcome, String? note, DateTime? nextOn, String? lostReason}) =>
      guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/leads/$id/follow-up', data: {
          'outcome': outcome,
          'note': ?note,
          if (nextOn != null) 'next_on': _day(nextOn),
          'lost_reason': ?lostReason,
        });
        return Enquiry.fromJson(res.data!['lead'] as Map<String, dynamic>);
      });

  /// Registers the enquiry as a member.
  Future<MemberCard> convertEnquiry(int id) => guardRequest(() async {
        final res = await _dio.post<Map<String, dynamic>>('/staff/leads/$id/convert', options: _once());
        return MemberCard.fromJson(res.data!['member'] as Map<String, dynamic>);
      });

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Classes ───────────────────────────────────────────────────────

  Future<List<ClassItem>> classes(DateTime day) => fetch(StaffReads.classes(day));

  Future<List<({MemberCard member, String status})>> roster(int classId) => fetch(StaffReads.roster(classId));

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

  Future<TrainerDashboard> trainerDashboard() => fetch(StaffReads.trainerDashboard);

  Future<TrainingSummary?> training(int memberId) => fetch(StaffReads.training(memberId));

  Future<List<TrainerNote>> notes(int memberId) => fetch(StaffReads.notes(memberId));

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

  Future<TodayReport> todayReport() => fetch(StaffReads.todayReport);

  Future<PeriodReport> periodReport(String period) => fetch(StaffReads.periodReport(period));
}

final staffApiProvider = Provider<StaffApi>((ref) => StaffApi(ref.watch(dioProvider)));
