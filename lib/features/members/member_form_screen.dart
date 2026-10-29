import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/toast.dart';
import '../desk/desk_providers.dart';
import 'member_providers.dart';

/// Correct a member's details: phone, name, ID number, status.
class EditMemberScreen extends ConsumerWidget {
  const EditMemberScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(memberProfileProvider(memberId));
    return profile.hasValue
        ? MemberFormScreen(existing: profile.requireValue)
        : AppPage(
            title: 'Edit member',
            body: AsyncView(
              value: profile,
              onRetry: () => ref.invalidate(memberProfileProvider(memberId)),
              data: (_) => const SizedBox.shrink(),
            ),
          );
  }
}

/// Every detail of a member. Registering at the desk is the shorter
/// register sheet; this is for corrections afterwards.
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, required this.existing});

  final MemberProfile existing;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing.card.name);
  late final _phone = TextEditingController(text: formatLocalPhone(widget.existing.card.phone).replaceAll(' ', ''));
  late final _email = TextEditingController(text: _detail('email'));
  late final _idNumber = TextEditingController(text: _detail('id_number'));
  late String? _gender = _detail('gender');
  late String _status = widget.existing.card.status;
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  String? _detail(String key) => widget.existing.details[key] as String?;

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
        // An emptied field is cleared.
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'id_number': _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
        'gender': _gender,
        'status': _status,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(staffApiProvider).updateMember(widget.existing.card.id, _fields());
      memberDataChanged(ref);
      if (!mounted) return;
      showToast(context, 'Changes saved');
      context.pop();
    } on ValidationFailure catch (e) {
      if (mounted) setState(() => _fieldErrors = e.fieldErrors);
      if (mounted && e.fieldErrors.isEmpty) setState(() => _error = e.message);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppPage(
      title: 'Edit member',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.sm, AppGutter.heading, AppSpace.xxxl),
          children: [
            AppField(
              label: 'Full name',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              error: _fieldErrors['name'],
              validator: (v) => (v ?? '').trim().isEmpty ? "Enter the member's name." : null,
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: 'Phone',
              controller: _phone,
              keyboardType: TextInputType.phone,
              hint: '0712 345 678',
              error: _fieldErrors['phone'],
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length >= 9 ? null : 'Enter a valid phone number.',
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: 'Email (optional)',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              error: _fieldErrors['email'],
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(label: 'ID number (optional)', controller: _idNumber, error: _fieldErrors['id_number']),
            const SizedBox(height: AppSpace.xl),
            Text('Gender', style: text.titleMedium),
            const SizedBox(height: AppSpace.sm),
            Wrap(spacing: AppSpace.sm, children: [
              for (final (value, label) in const [('female', 'Female'), ('male', 'Male'), ('other', 'Other')])
                PillChip(
                  label: label,
                  selected: _gender == value,
                  onTap: () => setState(() => _gender = _gender == value ? null : value),
                ),
            ]),
            const SizedBox(height: AppSpace.xl),
            Text('Status', style: text.titleMedium),
            const SizedBox(height: AppSpace.sm),
            PillSegmented<String>(
              options: const [('active', 'Active'), ('inactive', 'Inactive'), ('suspended', 'Suspended')],
              selected: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: AppSpace.sm),
            Text("Suspended and inactive members can't check in.", style: text.bodySmall),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.lg),
              FormErrorText(_error!),
            ],
            const SizedBox(height: AppSpace.xxl),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Save changes')),
          ],
        ),
      ),
    );
  }
}
