import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';
import '../auth/state/session_controller.dart';
import '../desk/desk_providers.dart';
import '../payments/pay_sheet.dart';
import 'member_providers.dart';
import 'member_sheet.dart';

/// Register someone at the counter, then go straight to their first
/// payment when this staff member can take one.
Future<void> showRegisterSheet(BuildContext context, WidgetRef ref) async {
  final result = await showAppSheet<Object>(context, builder: (_) => const RegisterSheet());
  if (!context.mounted) return;
  switch (result) {
    // They were already a member: open them instead.
    case (MemberCard existing, true):
      await showMemberSheet(context, existing);
    case MemberCard member:
      showToast(context, '${firstName(member.name)} registered · #${member.memberNumber}');
      if (ref.read(staffProvider).can('payments.record')) await showPaySheet(context, memberId: member.id);
  }
}

class RegisterSheet extends ConsumerStatefulWidget {
  const RegisterSheet({super.key});

  @override
  ConsumerState<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends ConsumerState<RegisterSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _nameError;
  String? _phoneError;
  String? _error;
  bool _duplicateRefused = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  /// The last nine digits, which match however the number was typed.
  String? get _last9 => _digits.length >= 9 ? _digits.substring(_digits.length - 9) : null;

  bool _validate() {
    final words = _name.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final phone = normalizeKenyanPhone(_phone.text);
    setState(() {
      _nameError = words.length < 2 ? 'Enter first and last name.' : null;
      _phoneError = phone.length == 12 && phone.startsWith('254') ? null : 'Enter a 10-digit phone number.';
    });
    return _nameError == null && _phoneError == null;
  }

  Future<void> _submit({bool confirmDuplicate = false}) async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(staffApiProvider).register(
        {'name': _name.text.trim(), 'phone': normalizeKenyanPhone(_phone.text)},
        confirmDuplicate: confirmDuplicate,
      );
      if (!mounted) return;
      switch (result) {
        case PossibleDuplicates(:final duplicates):
          setState(() {
            _duplicateRefused = true;
            _error = 'That number belongs to someone already: '
                '${duplicates.map((d) => '${d.name} (#${d.memberNumber})').join(', ')}. '
                'Check with the person before adding them again.';
          });
        case Registered(:final member):
          ref.invalidate(membersPageProvider);
          memberDataChanged(ref);
          Navigator.pop(context, member);
      }
    } on ValidationFailure catch (e) {
      if (mounted) {
        setState(() {
          _nameError = e.fieldErrors['name'] ?? _nameError;
          _phoneError = e.fieldErrors['phone'] ?? _phoneError;
          if (e.fieldErrors.isEmpty) _error = e.message;
        });
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final last9 = _last9;
    // Checked as they type: someone may already have this number.
    final match = last9 == null
        ? null
        : ref.watch(lookupProvider(last9)).value?.where((m) => m.phone.endsWith(last9)).firstOrNull;

    return SheetBody(children: [
      const SheetTitle('Register', subtitle: 'Name and phone now; the rest can wait.'),
      AppField(
        label: 'Full name',
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        error: _nameError,
        onChanged: (_) => _nameError == null ? null : setState(() => _nameError = null),
      ),
      const SizedBox(height: AppSpace.lg),
      AppField(
        label: 'Phone',
        controller: _phone,
        hint: '0712 345 678',
        keyboardType: TextInputType.phone,
        prefixIcon: AppIcons.phone,
        error: _phoneError,
        onChanged: (_) => setState(() {
          _phoneError = null;
          _duplicateRefused = false;
        }),
        onSubmitted: (_) => _submit(),
      ),
      if (match != null) ...[
        const SizedBox(height: AppSpace.lg),
        SurfaceCard(
          color: context.palette.warning.fill,
          radius: AppRadius.tile,
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(children: [
            MemberAvatar(initials: match.initials, photoUrl: match.photoUrl, seed: match.id),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${match.name} has this number',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.palette.warning.on)),
                Text('#${match.memberNumber} · ${membershipStatus(match).$1}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.warning.on)),
              ]),
            ),
            SmallPillButton(label: 'Open', onPressed: () => Navigator.pop(context, (match, true))),
          ]),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpace.lg),
        InfoCard(
          message: _error!,
          tone: Tone.warning,
          action: _duplicateRefused
              ? TextButton(onPressed: _busy ? null : () => _submit(confirmDuplicate: true), child: const Text('Add anyway'))
              : null,
        ),
      ],
      const SizedBox(height: AppSpace.xl),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy
            ? 'Registering…'
            : staff.can('payments.record')
                ? 'Register & take payment'
                : 'Register'),
      ),
    ]);
  }
}
