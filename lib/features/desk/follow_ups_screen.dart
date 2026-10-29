import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/url_opener.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../members/member_sheet.dart';

final followUpsProvider = FutureProvider.autoDispose<({List<FollowUp> expiring, List<FollowUp> lapsed})>(
  (ref) => ref.watch(staffApiProvider).followUps(),
);

const _intro = 'Ending in 7 days or lapsed. A reminder goes by WhatsApp.';

/// Who to remind this week, from Home's warning tiles.
Future<void> showFollowUpsSheet(BuildContext context) => showAppSheet<void>(
      context,
      builder: (_) => const SheetBody(children: [SheetTitle('Follow-ups', subtitle: _intro), FollowUpsList()]),
    );

/// The same list as a page, for links from notifications.
class FollowUpsScreen extends StatelessWidget {
  const FollowUpsScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppPage(
        title: 'Follow-ups',
        body: SheetBody(children: [Text(_intro), SizedBox(height: AppSpace.xl), FollowUpsList()]),
      );
}

/// Memberships ending in the next 7 days, then ones that ended in the last
/// 14 without a renewal. Trainers see their clients.
class FollowUpsList extends ConsumerStatefulWidget {
  const FollowUpsList({super.key});

  @override
  ConsumerState<FollowUpsList> createState() => _FollowUpsListState();
}

class _FollowUpsListState extends ConsumerState<FollowUpsList> {
  /// Reminded in this sheet, shown as "Sent".
  final _sent = <int>{};

  Future<void> _remind(FollowUp row) async {
    final gym = ref.read(staffProvider).gymName;
    final first = firstName(row.member.name);
    final plan = row.plan ?? 'gym';
    final message = row.days >= 0
        ? 'Hi $first, your $plan membership at $gym ends on ${formatDate(row.expiresAt)}. '
            'Renew at the front desk or in the ZoeziDesk app to keep training without a break.'
        : 'Hi $first, we miss you at $gym! Your $plan membership ended on ${formatDate(row.expiresAt)}. '
            'Renew at the front desk or in the ZoeziDesk app whenever you are ready.';
    final uri = Uri.https('wa.me', '/${normalizeKenyanPhone(row.member.phone)}', {'text': message});
    final opened = await ref.read(urlOpenerProvider)(uri);
    if (!mounted) return;
    if (opened) {
      setState(() => _sent.add(row.member.id));
      showToast(context, 'Reminder to $first opened in WhatsApp');
    } else {
      showToast(context, 'WhatsApp is not on this phone.');
    }
  }

  static String _status(FollowUp row) => switch (row.days) {
        0 => 'Ends today',
        > 0 => 'Ends ${formatShortDate(row.expiresAt)}',
        -1 => 'Ended yesterday',
        _ => 'Ended ${-row.days} days ago',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    return AsyncView(
      value: ref.watch(followUpsProvider),
      onRetry: () => ref.invalidate(followUpsProvider),
      loading: const SkeletonList.inline(),
      data: (f) {
        final rows = [...f.expiring, ...f.lapsed];
        if (rows.isEmpty) {
          return const StateMessage.empty(
            title: 'Nobody to follow up',
            message: 'No memberships end this week, and nobody has lapsed in the last two weeks.',
          );
        }
        return Column(children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                onTap: () => showMemberSheet(context, row.member),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    MemberAvatar(initials: row.member.initials, photoUrl: row.member.photoUrl, seed: row.member.id),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(row.member.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_status(row), style: text.bodySmall?.copyWith(color: p.warning.on, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Opacity(
                      opacity: _sent.contains(row.member.id) ? 0.45 : 1,
                      child: SmallPillButton(
                        label: _sent.contains(row.member.id) ? 'Sent' : 'Remind',
                        filled: false,
                        onPressed: _sent.contains(row.member.id) ? null : () => _remind(row),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
