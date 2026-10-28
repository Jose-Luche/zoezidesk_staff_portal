import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../auth/state/session_controller.dart';
import '../auth/widgets/auth_scaffold.dart';
import '../desk/desk_providers.dart';
import 'member_providers.dart';

/// Register a new member at the front desk. If the phone or ID number is
/// already on file, the possible matches are shown first.
class NewMemberScreen extends StatelessWidget {
  const NewMemberScreen({super.key});

  @override
  Widget build(BuildContext context) => const MemberFormScreen();
}

/// Correct a member's details: phone, name, ID number, status.
class EditMemberScreen extends ConsumerWidget {
  const EditMemberScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(memberProfileProvider(memberId));
    return profile.hasValue
        ? MemberFormScreen(existing: profile.requireValue)
        : Scaffold(
            appBar: AppBar(title: const Text('Edit member')),
            body: AsyncView(
              value: profile,
              onRetry: () => ref.invalidate(memberProfileProvider(memberId)),
              data: (_) => const SizedBox.shrink(),
            ),
          );
  }
}

/// The member form, for registering ([existing] null) or editing.
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.existing});

  final MemberProfile? existing;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.card.name);
  late final _phone = TextEditingController(
    text: widget.existing == null ? null : formatLocalPhone(widget.existing!.card.phone).replaceAll(' ', ''),
  );
  late final _email = TextEditingController(text: _detail('email'));
  late final _idNumber = TextEditingController(text: _detail('id_number'));
  late String? _gender = _detail('gender');
  late String _status = widget.existing?.card.status ?? 'active';
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  bool get _editing => widget.existing != null;

  String? _detail(String key) => widget.existing?.details[key] as String?;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _idNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _fields() => {
        'name': _name.text.trim(),
        // Stored as 2547…, like the rest of the system.
        'phone': normalizeKenyanPhone(_phone.text),
        // On edit, an emptied field is cleared; on registration it is just left out.
        if (_editing || _email.text.trim().isNotEmpty) 'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        if (_editing || _idNumber.text.trim().isNotEmpty)
          'id_number': _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
        if (_editing || _gender != null) 'gender': _gender,
        if (_editing) 'status': _status,
      };

  Future<void> _submit({bool confirmDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    final api = ref.read(staffApiProvider);
    try {
      if (_editing) {
        await api.updateMember(widget.existing!.card.id, _fields());
        memberDataChanged(ref);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member updated.')));
        context.pop();
        return;
      }
      final result = await api.register(_fields(), confirmDuplicate: confirmDuplicate);
      if (!mounted) return;
      switch (result) {
        case PossibleDuplicates(:final duplicates):
          if (await _confirm(duplicates) == true) await _submit(confirmDuplicate: true);
        case Registered(:final member):
          ref.invalidate(membersPageProvider);
          await _done(member);
      }
    } on ValidationFailure catch (e) {
      if (mounted) setState(() => _fieldErrors = e.fieldErrors);
      if (mounted && e.fieldErrors.isEmpty) setState(() => _error = e.message);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(List<PossibleDuplicate> duplicates) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already a member?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('These members have the same details:'),
            const SizedBox(height: AppSpace.sm),
            for (final d in duplicates) Text('• ${d.name} (${d.memberNumber}): same ${d.matched}'),
            const SizedBox(height: AppSpace.sm),
            const Text('Check with the person before adding them again.'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save anyway')),
          ],
        ),
      );

  Future<void> _done(MemberCard member) async {
    final staff = ref.read(staffProvider);
    final pay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded, color: context.palette.success, size: AppSpace.xxl),
        title: Text('${member.name} registered'),
        content: Text('Member number ${member.memberNumber}. They can now sign in to the members app with their phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Done')),
          if (staff.can('payments.record'))
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Take first payment')),
        ],
      ),
    );
    if (!mounted) return;
    pay == true ? context.pushReplacement(Routes.pay(member.id)) : context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit member' : 'Register member')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Full name', errorText: _fieldErrors['name']),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the member\'s name.' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Phone', hintText: '0712 345 678', errorText: _fieldErrors['phone']),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length >= 9 ? null : 'Enter a valid phone number.',
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email (optional)', errorText: _fieldErrors['email']),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _idNumber,
              decoration: InputDecoration(labelText: 'ID number (optional)', errorText: _fieldErrors['id_number']),
            ),
            const SizedBox(height: AppSpace.md),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender (optional)'),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            if (_editing) ...[
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  helperText: 'Suspended and inactive members can\'t check in.',
                  helperMaxLines: 2,
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              FormErrorText(_error!),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving…' : (_editing ? 'Save changes' : 'Register')),
            ),
          ],
        ),
      ),
    );
  }
}
