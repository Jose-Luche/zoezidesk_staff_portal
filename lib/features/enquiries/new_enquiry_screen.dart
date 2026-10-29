import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../auth/widgets/auth_scaffold.dart';
import 'enquiries_screen.dart';

/// Someone walks in asking about the gym: name, phone, what they want, and
/// when to call them back.
class NewEnquiryScreen extends ConsumerStatefulWidget {
  const NewEnquiryScreen({super.key});

  @override
  ConsumerState<NewEnquiryScreen> createState() => _NewEnquiryScreenState();
}

class _NewEnquiryScreenState extends ConsumerState<NewEnquiryScreen> {
  static const _sources = {'walk_in': 'Walked in', 'phone': 'Phoned', 'referral': 'Referred', 'social_media': 'Social media'};

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _interest = TextEditingController();
  final _notes = TextEditingController();
  String _source = 'walk_in';
  DateTime? _followUpOn = DateTime.now().add(const Duration(days: 2));
  bool _welcome = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _interest, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({bool confirm = false}) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(staffApiProvider).recordEnquiry({
        'name': _name.text.trim(),
        'phone': normalizeKenyanPhone(_phone.text),
        'source': _source,
        if (_interest.text.trim().isNotEmpty) 'interested_in_plan': _interest.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (_followUpOn != null)
          'follow_up_on':
              '${_followUpOn!.year}-${_followUpOn!.month.toString().padLeft(2, '0')}-${_followUpOn!.day.toString().padLeft(2, '0')}',
        'send_welcome': _welcome,
      }, confirm: confirm);
      if (!mounted) return;

      switch (result) {
        case EnquiryRecorded(:final welcomeSent):
          ref.invalidate(enquiriesProvider);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_welcome && welcomeSent ? 'Enquiry saved and welcome WhatsApp sent.' : 'Enquiry saved.'),
          ));
          context.pop();
        case AlreadyAMember(:final message, :final memberId):
          final open = await _ask('Already a member', message, 'Open member');
          if (open == true && mounted) context.pushReplacement(Routes.member(memberId));
        case AlreadyEnquired(:final message):
          final again = await _ask('Enquired before', '$message Record this visit as well?', 'Save anyway');
          if (again == true) await _submit(confirm: true);
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _ask(String title, String message, String action) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go back')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New enquiry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter their name.' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone', hintText: '0712 345 678'),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length >= 9 ? null : 'Enter a valid phone number.',
            ),
            const SizedBox(height: AppSpace.md),
            Wrap(spacing: AppSpace.sm, children: [
              for (final MapEntry(:key, :value) in _sources.entries)
                ChoiceChip(label: Text(value), selected: _source == key, onSelected: (_) => setState(() => _source = key)),
            ]),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _interest,
              decoration: const InputDecoration(labelText: 'Interested in (optional)', hintText: 'e.g. Monthly, evening classes'),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Goals, questions, best time to call'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text(_followUpOn == null ? 'No follow-up call' : 'Call them back ${formatDate(_followUpOn!)}'),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _followUpOn ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _followUpOn = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _welcome,
              onChanged: (v) => setState(() => _welcome = v),
              title: const Text('Send a welcome WhatsApp'),
              subtitle: const Text('If the gym has WhatsApp set up'),
            ),
            if (_error != null) FormErrorText(_error!),
            const SizedBox(height: AppSpace.lg),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Save enquiry')),
          ],
        ),
      ),
    );
  }
}
