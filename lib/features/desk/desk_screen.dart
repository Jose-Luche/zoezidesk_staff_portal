import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
import 'desk_providers.dart';
import 'member_actions.dart';

/// The front desk: scan first, then find a member by name, phone or number
/// to check them in or take a payment.
class DeskScreen extends ConsumerStatefulWidget {
  const DeskScreen({super.key});

  @override
  ConsumerState<DeskScreen> createState() => _DeskScreenState();
}

class _DeskScreenState extends ConsumerState<DeskScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final today = ref.watch(todayCheckInsProvider);
    final text = Theme.of(context).textTheme;
    final searching = _query.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Front desk'),
        actions: [
          IconButton(
            tooltip: 'Follow-ups',
            icon: const Icon(Icons.event_busy_rounded),
            onPressed: () => context.push(Routes.followUps),
          ),
          if (staff.can('payments.record', 'payments.view'))
            IconButton(
              tooltip: 'My shift',
              icon: const Icon(Icons.receipt_long_rounded),
              onPressed: () => context.push(Routes.shift),
            ),
        ],
      ),
      floatingActionButton: staff.can('members.create')
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newMember),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Register'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(todayCheckInsProvider.future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpace.xxxl + AppSpace.lg),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpace.xxxl + AppSpace.md)),
                onPressed: () => context.push(Routes.scan),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: AppSpace.xl),
                label: Text('Scan member QR', style: text.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Find a member',
                  hintText: 'Name, phone or member number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            if (searching)
              AsyncView(
                value: ref.watch(lookupProvider(_query)),
                onRetry: () => ref.invalidate(lookupProvider(_query)),
                loading: const SkeletonList.inline(),
                data: (found) => found.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpace.lg),
                        child: StateMessage.empty(title: 'No match', message: 'Try part of the name, or the phone number.'),
                      )
                    : Column(children: [
                        for (final m in found) MemberTile(member: m, onTap: () => showMemberActions(context, m)),
                      ]),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.sm),
                child: Text(
                  'Checked in today${today.hasValue ? ' · ${today.requireValue.count}' : ''}',
                  style: text.titleMedium,
                ),
              ),
              AsyncView(
                value: today,
                onRetry: () => ref.invalidate(todayCheckInsProvider),
                loading: const SkeletonList.inline(),
                data: (data) => data.checkIns.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpace.lg),
                        child: StateMessage.empty(title: 'No check-ins yet', message: 'Scanned members show up here.'),
                      )
                    : Column(children: [
                        for (final c in data.checkIns)
                          MemberTile(
                            member: c.member,
                            subtitle: '${DateFormat.Hm().format(c.at)} · ${c.method == 'qr' ? 'QR' : 'By hand'}'
                                '${c.by == null ? '' : ' · ${c.by}'}',
                            onTap: () => showMemberActions(context, c.member),
                          ),
                      ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
