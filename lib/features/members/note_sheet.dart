import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../data/models/work.dart';
import '../../data/repositories/outbox.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../sync/queued_actions.dart';
import 'member_providers.dart';

/// Opens the note sheet; on save a toast says whether it is in or waiting
/// for the connection (the notes refresh once it is sent).
Future<void> showNoteSheet(BuildContext context, WidgetRef ref, MemberCard member) async {
  final saved = await showAppSheet<String>(context, builder: (_) => NoteSheet(member: member));
  if (saved != null && context.mounted) showToast(context, saved);
}

/// A quick note after a session: type chips, then the text.
class NoteSheet extends ConsumerStatefulWidget {
  const NoteSheet({super.key, required this.member});

  final MemberCard member;

  @override
  ConsumerState<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<NoteSheet> {
  static const _types = {'session': 'Session', 'progress': 'Progress', 'health': 'Health', 'general': 'General'};

  final _note = TextEditingController();
  String _type = 'session';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_note.text.trim().length < 5) return setState(() => _error = 'Write at least a few words.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final now = DateTime.now();
    final Delivery delivery;
    try {
      delivery = await ref.read(outboxProvider.notifier).submit(
        QueuedKinds.note,
        {
          'member_id': widget.member.id,
          'type': _type,
          'note': _note.text.trim(),
          'session_date': DateTime(now.year, now.month, now.day).toIso8601String(),
        },
        label: widget.member.name,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failureMessage(e);
        });
      }
      return;
    }
    if (!mounted) return;
    switch (delivery) {
      case Delivered():
        Navigator.pop(context, 'Note saved');
      case Queued():
        Navigator.pop(context, 'Note saved offline. It goes when the connection is back.');
      case Refused(:final message):
        setState(() {
          _busy = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(children: [
      SheetTitle('New note · ${firstName(widget.member.name)}'),
      Wrap(spacing: AppSpace.sm, children: [
        for (final MapEntry(:key, :value) in _types.entries)
          PillChip(label: value, sage: true, selected: _type == key, onTap: () => setState(() => _type = key)),
      ]),
      if (_type == 'health') ...[
        const SizedBox(height: AppSpace.md),
        const InfoCard(message: 'Health notes are only seen by trainers, managers and owners.', icon: AppIcons.lock),
      ],
      const SizedBox(height: AppSpace.xl),
      AppField(
        label: 'Note',
        controller: _note,
        autofocus: true,
        minLines: 4,
        maxLines: 8,
        maxLength: 1000,
        hint: "What did you work on? What's next?",
        error: _error,
      ),
      const SizedBox(height: AppSpace.lg),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save note')),
    ]);
  }
}

/// A note saved offline, not yet sent: shown above the member's notes.
class PendingNoteCard extends StatelessWidget {
  const PendingNoteCard({super.key, required this.item});

  final OutboxItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      radius: AppRadius.tile,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const AppTag(label: 'Pending', tone: Tone.warning),
          const SizedBox(width: AppSpace.sm),
          Flexible(child: Text('Waiting to send', style: text.bodySmall)),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text(item.payload['note'] as String, style: text.bodyMedium),
      ]),
    );
  }
}

/// One trainer note: "{type} · {date} · {trainer}" over the text. The
/// author can delete their own.
class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note, this.memberId, this.showMember = false, this.onTap});

  final TrainerNote note;

  /// To refresh the member's notes after a delete; null hides delete.
  final int? memberId;
  final bool showMember;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final id = memberId;
    return SurfaceCard(
      onTap: onTap,
      radius: AppRadius.tile,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AppTag(label: note.typeLabel, tone: note.type == 'health' ? Tone.warning : Tone.success),
              const SizedBox(width: AppSpace.sm),
              Flexible(
                child: Text(
                  [
                    if (showMember && note.member != null) note.member!,
                    formatShortDate(note.sessionDate),
                    if (!showMember && note.trainer != null) note.trainer!,
                  ].join(' · '),
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(note.note, style: text.bodyMedium, maxLines: showMember ? 3 : null, overflow: showMember ? TextOverflow.ellipsis : null),
          ]),
        ),
        if (note.mine && id != null)
          IconButton(
            tooltip: 'Delete note',
            icon: const Icon(AppIcons.delete, size: AppIconSize.sm),
            onPressed: () async {
              try {
                await ref.read(staffApiProvider).deleteNote(note.id);
                ref.invalidate(memberNotesProvider(id));
                if (context.mounted) showToast(context, 'Note deleted');
              } catch (e) {
                if (context.mounted) showToast(context, failureMessage(e));
              }
            },
          ),
      ]),
    );
  }
}
