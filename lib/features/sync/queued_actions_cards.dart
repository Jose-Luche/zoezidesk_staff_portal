import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/outbox.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import 'queued_actions.dart';

/// What a queued action is, for the cards: "Note for Jane".
String describeQueued(OutboxItem item) {
  final who = item.label == null ? '' : ' ${item.label}';
  return switch (item.kind) {
    QueuedKinds.book => 'Booking$who',
    QueuedKinds.cancelBooking => 'Cancelling$who',
    QueuedKinds.attended => item.payload['attended'] == true ? 'Ticking off$who' : 'Unticking$who',
    QueuedKinds.note => 'Note for$who',
    _ => 'Change$who',
  };
}

/// Class changes and notes saved offline: how many are waiting, with Send,
/// and any the server refused once sent, with Dismiss. Check-ins have their
/// own cards on the desk (OfflineDesk). Nothing when there is nothing.
List<Widget> queuedActionCards(BuildContext context, WidgetRef ref, {required bool sending, required VoidCallback onSend}) {
  final items = ref.watch(outboxProvider).where((i) => i.kind != QueuedKinds.checkIn).toList();
  final waiting = items.where((i) => i.waiting).toList();
  final refused = items.where((i) => i.status == OutboxStatus.failed).toList();
  return [
    if (waiting.isNotEmpty)
      ActionCard(
        tone: Tone.warning,
        badge: Text('${waiting.length}'),
        title: '${waiting.length} change${waiting.length == 1 ? '' : 's'} waiting to send',
        subtitle: 'Saved offline at ${formatTime(waiting.last.createdAt.toLocal())}',
        actionLabel: sending ? 'Sending…' : 'Send',
        onAction: sending ? null : onSend,
      ),
    if (refused.isNotEmpty)
      ActionCard(
        tone: Tone.danger,
        badge: const Icon(AppIcons.refused),
        title: 'Refused when sent',
        subtitle: refused.map((r) => '${describeQueued(r)}: ${r.message ?? ''}').join('\n'),
        actionLabel: 'Dismiss',
        onAction: () async {
          final outbox = ref.read(outboxProvider.notifier);
          for (final kind in {for (final r in refused) r.kind}) {
            await outbox.dismissRefused(kind);
          }
        },
      ),
  ];
}

/// [queuedActionCards] as a block for a Home, with its own Send.
class QueuedActionsCards extends ConsumerStatefulWidget {
  const QueuedActionsCards({super.key});

  @override
  ConsumerState<QueuedActionsCards> createState() => _QueuedActionsCardsState();
}

class _QueuedActionsCardsState extends ConsumerState<QueuedActionsCards> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    await sendQueued(context, ref);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final cards = queuedActionCards(context, ref, sending: _sending, onSend: _send);
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGutter.cards, AppSpace.lg, AppGutter.cards, 0),
      child: Column(children: [
        for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: AppSpace.sm), child: c),
      ]),
    );
  }
}

/// Sends what is waiting now and says how it went.
Future<void> sendQueued(BuildContext context, WidgetRef ref) async {
  final outbox = ref.read(outboxProvider.notifier);
  final before = await outbox.waitingCount();
  await outbox.flush(force: true);
  final left = await outbox.waitingCount();
  if (!context.mounted) return;
  showToast(
    context,
    left == 0
        ? 'Sent'
        : left < before
            ? '${before - left} sent, $left still waiting'
            : 'Still offline. They go when the connection is back.',
  );
}
