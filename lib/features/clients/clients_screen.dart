import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/work.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/state_message.dart';
import '../members/member_providers.dart';

/// A trainer's day: who needs a nudge, then all their clients.
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(trainerDashboardProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My clients')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(trainerDashboardProvider.future),
        child: AsyncView(
          value: dashboard,
          onRetry: () => ref.invalidate(trainerDashboardProvider),
          data: (d) => d.clients.isEmpty
              ? ListView(children: const [
                  SizedBox(height: AppSpace.xxxl),
                  StateMessage.empty(
                    title: 'No clients yet',
                    message: 'A manager assigns members to you on the web staff page.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Text(
                        '${d.clients.length} client${d.clients.length == 1 ? '' : 's'} · '
                        '${d.checkInsToday} checked in today',
                        style: text.bodyLarge,
                      ),
                    ),
                    if (d.needsAttention.isNotEmpty) ...[
                      _Heading('Needs attention'),
                      for (final row in d.needsAttention)
                        _ClientTile(client: row.client, flag: row.inactive ? 'Not training' : null),
                    ],
                    if (d.expiringSoon.isNotEmpty) ...[
                      _Heading('Membership ending soon'),
                      for (final m in d.expiringSoon) MemberTile(member: m, onTap: () => context.push(Routes.member(m.id))),
                    ],
                    _Heading('All clients'),
                    for (final c in d.clients) _ClientTile(client: c),
                    if (d.recentNotes.isNotEmpty) ...[
                      _Heading('Your recent notes'),
                      for (final n in d.recentNotes)
                        ListTile(
                          title: Text(n.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${n.member ?? ''} · ${n.typeLabel} · ${formatDate(n.sessionDate)}'),
                        ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.xs),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, this.flag});

  final TrainerClient client;
  final String? flag;

  @override
  Widget build(BuildContext context) {
    final t = client.training;
    final days = t?.daysSinceWorkout;
    return ListTile(
      onTap: () => context.push(Routes.member(client.card.id)),
      leading: MemberAvatar(initials: client.card.initials),
      title: Text(client.card.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
          Text(days == null ? 'No workouts yet' : 'Trained ${days == 0 ? 'today' : '$days d ago'}'),
          if (flag != null) AppBadge(label: flag!, tone: BadgeTone.danger),
          for (final a in (t?.attention ?? const <({String muscle, String status})>[]).take(2))
            AppBadge(label: a.muscle, tone: a.status == 'declining' ? BadgeTone.danger : BadgeTone.warning),
        ]),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
