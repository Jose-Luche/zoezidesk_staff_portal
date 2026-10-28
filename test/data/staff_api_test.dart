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
}
