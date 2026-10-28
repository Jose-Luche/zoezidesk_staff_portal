import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_opener.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
import 'member_actions.dart';

final followUpsProvider = FutureProvider.autoDispose<({List<FollowUp> expiring, List<FollowUp> lapsed})>(
  (ref) => ref.watch(staffApiProvider).followUps(),
);

/// Who to call this week: memberships ending in the next 7 days, and ones
/// that ended in the last 14 without a renewal. Trainers see their clients.
class FollowUpsScreen extends ConsumerWidget {
  const FollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUps = ref.watch(followUpsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Follow-ups')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(followUpsProvider.future),
        child: AsyncView(
          value: followUps,
          onRetry: () => ref.invalidate(followUpsProvider),
          data: (f) => f.expiring.isEmpty && f.lapsed.isEmpty
              ? ListView(children: const [
                  SizedBox(height: AppSpace.xxxl),
                  StateMessage.empty(
                    title: 'Nobody to follow up',
                    message: 'No memberships end this week, and nobody has lapsed in the last two weeks.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
                  children: [
                    if (f.expiring.isNotEmpty) ...[
                      _Heading('Ending in the next 7 days', f.expiring.length),
                      for (final row in f.expiring) _FollowUpTile(row: row),
                    ],
                    if (f.lapsed.isNotEmpty) ...[
                      _Heading('Ended in the last 14 days', f.lapsed.length),
                      for (final row in f.lapsed) _FollowUpTile(row: row),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.xs),
        child: Text('$title · $count', style: Theme.of(context).textTheme.titleLarge),
      );
}

class _FollowUpTile extends ConsumerWidget {
  const _FollowUpTile({required this.row});

  final FollowUp row;

  /// Only for lapsed members: for the others, the membership badge already
  /// says how many days are left.
  String? get _ended => switch (row.days) {
        >= 0 => null,
        -1 => 'Ended yesterday',
        _ => 'Ended ${-row.days} days ago',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gym = ref.watch(staffProvider).gymName;
    final open = ref.watch(urlOpenerProvider);
    final phone = normalizeKenyanPhone(row.member.phone);
    final firstName = row.member.name.split(' ').first;
    final plan = row.plan ?? 'gym';
    final message = row.days >= 0
        ? 'Hi $firstName, your $plan membership at $gym ends on ${formatDate(row.expiresAt)}. '
            'Renew at the front desk or in the ZoeziDesk app to keep training without a break.'
        : 'Hi $firstName, we miss you at $gym! Your $plan membership ended on ${formatDate(row.expiresAt)}. '
            'Renew at the front desk or in the ZoeziDesk app whenever you are ready.';

    Future<void> launch(Uri uri) async {
      if (!await open(uri) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app on this phone can open that.')));
      }
    }

    return MemberTile(
      member: row.member,
      subtitle: [?_ended, formatLocalPhone(row.member.phone)].join(' · '),
      onTap: () => showMemberActions(context, row.member),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Call ${row.member.name}',
          icon: const Icon(Icons.call_rounded),
          onPressed: () => launch(Uri(scheme: 'tel', path: '+$phone')),
        ),
        IconButton(
          tooltip: 'WhatsApp ${row.member.name}',
          icon: const Icon(Icons.chat_rounded),
          onPressed: () => launch(Uri.https('wa.me', '/$phone', {'text': message})),
        ),
      ]),
    );
  }
}
