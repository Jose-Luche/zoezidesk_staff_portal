import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoezidesk_staff/core/network/retry_interceptor.dart';
import 'package:zoezidesk_staff/data/api/staff_api.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAdapter adapter;
  late StaffApi api;

  Map<String, dynamic> card({int id = 12, bool current = true}) => {
        'id': id,
        'name': 'Jane Wanjiku',
        'initials': 'JW',
        'member_number': 'TG-0012',
        'phone': '254711000001',
        'photo_url': null,
        'status': 'active',
        'membership': {'plan': 'Monthly', 'expires_at': '2026-11-19', 'days_left': 20, 'current': current},
      };

  setUp(() {
    adapter = FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
    api = StaffApi(dio);
  });

  test('a refused check-in is a result to show, not an error', () async {
    adapter.reply(422, {
      'success': false,
      'duplicate': false,
      'message': 'No active membership. Renewal required.',
      'member': card(current: false),
    });

    final result = await api.checkIn(qrCode: 'abc');

    expect(result.success, isFalse);
    expect(result.message, 'No active membership. Renewal required.');
    expect(result.member!.isCurrent, isFalse);
    expect(adapter.requests.single.headers[RetryInterceptor.idempotencyHeader], isNotEmpty);
  });

  test('registering returns the possible duplicates on 409', () async {
    adapter.reply(409, {
      'success': false,
      'code': 'possible_duplicate',
      'duplicates': [
        {'id': 3, 'name': 'Jane W', 'member_number': 'TG-0003', 'matched': 'phone 254711000001'},
      ],
    });

    final result = await api.register({'name': 'Jane', 'phone': '0711000001'});

    expect(result, isA<PossibleDuplicates>());
    expect((result as PossibleDuplicates).duplicates.single.id, 3);
  });

  test('confirming a duplicate sends confirm_duplicate', () async {
    adapter.reply(201, {'success': true, 'member': card()});

    final result = await api.register({'name': 'Jane', 'phone': '0711000001'}, confirmDuplicate: true);

    expect(result, isA<Registered>());
    expect((adapter.requests.single.data as Map)['confirm_duplicate'], isTrue);
  });

  test('every payment sends its own idempotency key', () async {
    final payment = {'id': 1, 'amount': 3000, 'method': 'cash', 'status': 'completed', 'has_receipt': true};
    adapter
      ..reply(201, {'success': true, 'payment': payment})
      ..reply(201, {'success': true, 'payment': payment});

    await api.payCash(memberId: 12, planId: 1, amount: 3000, method: 'cash');
    await api.payCash(memberId: 12, planId: 1, amount: 3000, method: 'cash');

    final keys = [for (final r in adapter.requests) r.headers[RetryInterceptor.idempotencyHeader]];
    expect(keys.toSet().length, 2);
  });

  test('the shift cash-up parses totals and, for managers, everyone', () async {
    adapter.reply(200, {
      'success': true,
      'date': '2026-10-30',
      'staff_id': 7,
      'summary': {
        'by_method': {'cash': {'count': 1, 'amount': 3000}, 'mpesa': {'count': 0, 'amount': 0}, 'bank': {'count': 0, 'amount': 0}},
        'count': 1,
        'total': 3000,
        'voided_count': 1,
        'voided_amount': 500,
      },
      'payments': [],
      'everyone': [
        {'staff': {'id': 7, 'name': 'Amina'}, 'total': 3000, 'count': 1},
      ],
    });

    final shift = await api.shift();

    expect(shift.total, 3000);
    expect(shift.byMethod['cash'], 3000);
    expect(shift.voidedAmount, 500);
    expect(shift.everyone!.single.name, 'Amina');
  });

  test('follow-ups come back as ending soon and lapsed', () async {
    adapter.reply(200, {
      'success': true,
      'expiring': [
        {'member': card(), 'plan': 'Monthly', 'expires_at': '2026-11-02', 'days': 3},
      ],
      'lapsed': [
        {'member': card(id: 13, current: false), 'plan': 'Monthly', 'expires_at': '2026-10-20', 'days': -10},
      ],
    });

    final f = await api.followUps();

    expect(f.expiring.single.days, 3);
    expect(f.lapsed.single.member.id, 13);
    expect(adapter.requests.single.queryParameters, {'days': 7, 'lapsed_days': 14});
  });

  test('booking a member into a class is safe to retry', () async {
    adapter.reply(200, {'success': true, 'message': 'Jane Wanjiku is booked in.', 'booked': 1});

    expect(await api.bookClass(5, 12), 'Jane Wanjiku is booked in.');
    expect(adapter.requests.single.path, '/staff/classes/5/bookings');
    expect(adapter.requests.single.headers[RetryInterceptor.idempotencyHeader], isNotEmpty);
  });

  test('a receipt link is fetched for opening or sending', () async {
    adapter.reply(200, {'success': true, 'url': 'https://api.test/member/receipts/9?signature=abc', 'expires_at': '2026-11-05T10:00:00+03:00'});

    expect(await api.receiptLink(9), 'https://api.test/member/receipts/9?signature=abc');
    expect(adapter.requests.single.path, '/staff/payments/9/receipt-link');
  });

  test('voiding sends the reason and returns the voided payment', () async {
    adapter.reply(200, {
      'success': true,
      'payment': {'id': 9, 'amount': 3000, 'method': 'cash', 'status': 'voided', 'void_reason': 'Recorded twice', 'member_phone': '254711000001'},
    });

    final p = await api.voidPayment(9, 'Recorded twice');

    expect(p.status, 'voided');
    expect(p.memberPhone, '254711000001');
    expect(adapter.requests.single.data, {'reason': 'Recorded twice'});
  });

  Map<String, dynamic> lead({String stage = 'new'}) => {
        'id': 4, 'name': 'Kevin Walk-in', 'phone': '254722111222', 'stage': stage, 'stage_label': 'New',
        'source': 'walk_in', 'interested_in_plan': 'Monthly', 'next_follow_up_at': null, 'overdue': false,
        'created_at': '2026-10-30T09:00:00+03:00',
      };

  test('recording an enquiry tells saved, already a member and enquired before apart', () async {
    adapter
      ..reply(201, {'success': true, 'welcome_sent': true, 'lead': lead()})
      ..reply(409, {'success': false, 'code': 'already_member', 'message': 'Jane is already a member.', 'member_id': 12})
      ..reply(409, {'success': false, 'code': 'existing_enquiry', 'message': 'Kevin already enquired.', 'lead': lead()});

    final saved = await api.recordEnquiry({'name': 'Kevin', 'phone': '254722111222'});
    final member = await api.recordEnquiry({'name': 'Jane', 'phone': '254711000001'});
    final again = await api.recordEnquiry({'name': 'Kevin', 'phone': '254722111222'});

    expect((saved as EnquiryRecorded).welcomeSent, isTrue);
    expect((member as AlreadyAMember).memberId, 12);
    expect((again as AlreadyEnquired).enquiry.id, 4);
    expect(adapter.requests.first.headers[RetryInterceptor.idempotencyHeader], isNotEmpty);
  });

  test('a follow-up sends the outcome and the next call day', () async {
    adapter.reply(200, {'success': true, 'lead': lead(stage: 'interested')});

    final e = await api.followUpEnquiry(4, outcome: 'interested', nextOn: DateTime(2026, 11, 2));

    expect(e.stage, 'interested');
    expect(adapter.requests.single.data, {'outcome': 'interested', 'next_on': '2026-11-02'});
  });
}
