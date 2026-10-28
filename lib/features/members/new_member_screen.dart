import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../auth/state/session_controller.dart';
import '../auth/widgets/auth_scaffold.dart';
import 'member_providers.dart';

/// Register a new member at the front desk. If the phone or ID number is
/// already on file, the possible matches are shown first.
class NewMemberScreen extends ConsumerStatefulWidget {
  const NewMemberScreen({super.key});

  @override
  ConsumerState<NewMemberScreen> createState() => _NewMemberScreenState();
}

class _NewMemberScreenState extends ConsumerState<NewMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _idNumber = TextEditingController();
  String? _gender;
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _idNumber]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({bool confirmDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final result = await ref.read(staffApiProvider).register({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_idNumber.text.trim().isNotEmpty) 'id_number': _idNumber.text.trim(),
        'gender': ?_gender,
      }, confirmDuplicate: confirmDuplicate);
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
      appBar: AppBar(title: const Text('Register member')),
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
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              FormErrorText(_error!),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Register')),
          ],
        ),
      ),
    );
  }
}
