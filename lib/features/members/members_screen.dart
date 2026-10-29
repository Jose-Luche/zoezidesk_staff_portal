import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
import '../desk/desk_providers.dart';
import '../desk/follow_ups_screen.dart';
import 'member_providers.dart';
import 'member_sheet.dart';
import 'register_sheet.dart';

enum _Filter {
  all('All'),
  inToday('In today'),
  ending('Ending soon'),
  expired('Expired');

  const _Filter(this.label);

  final String label;
}

/// Everyone at the gym, or a trainer's own clients ([clientsOnly]): a
/// search pill, filter chips, and rows that open the member sheet.
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key, this.clientsOnly = false});

  final bool clientsOnly;

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _Filter _filter = _Filter.all;
  int _pages = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        // From two characters: name, phone digits or member number.
        _query = value.trim().length >= 2 ? value.trim() : '';
        _pages = 1;
      });
    });
  }

  bool _matches(MemberCard m) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final digits = _query.replaceAll(RegExp(r'\D'), '');
    return m.name.toLowerCase().contains(q) ||
        m.memberNumber.toLowerCase().contains(q) ||
        (digits.length >= 2 && m.phone.contains(digits.startsWith('0') ? digits.substring(1) : digits));
  }

  Future<void> _refresh() async {
    setState(() => _pages = 1);
    ref
      ..invalidate(membersPageProvider)
      ..invalidate(trainerDashboardProvider)
      ..invalidate(followUpsProvider)
      ..invalidate(todayCheckInsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final today = staff.can('checkin.scan') ? ref.watch(todayCheckInsProvider).value?.checkIns : null;
    final inToday = <int, TodayCheckIn>{};
    for (final c in today ?? const <TodayCheckIn>[]) {
      inToday.putIfAbsent(c.member.id, () => c);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppGutter.belowNav),
            children: [
              TabHeadline(
                widget.clientsOnly ? 'My clients' : 'Members',
                action: !widget.clientsOnly && staff.can('members.create')
                    ? TextButton.icon(
                        onPressed: () => showRegisterSheet(context, ref),
                        icon: const Icon(AppIcons.add, size: AppIconSize.sm),
                        label: const Text('Register'),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards),
                child: TextField(
                  controller: _search,
                  onChanged: (v) {
                    setState(() {});
                    _onSearch(v);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Name, phone or member number',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: AppSpace.lg, right: AppSpace.sm),
                      child: Icon(AppIcons.search, size: AppIconSize.md),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: AppSizes.minTouch, minHeight: AppSizes.minTouch),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(AppIcons.close, size: AppIconSize.sm),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              ChipRow(children: [
                for (final f in _Filter.values)
                  if (f != _Filter.inToday || today != null)
                    PillChip(label: f.label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
              ]),
              const SizedBox(height: AppSpace.sm),
              _list(inToday),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rows(Iterable<MemberCard> members, Map<int, TodayCheckIn> inToday) {
    final list = members.where(_matches).toList();
    if (list.isEmpty) {
      return const StateMessage.empty(title: 'No match', message: 'Try part of the name, or the phone number.');
    }
    return Column(children: [
      for (final m in list)
        MemberRow(
          member: m,
          inAt: inToday[m.id]?.at,
          inBy: inToday[m.id]?.method,
          onTap: () => showMemberSheet(context, m),
        ),
    ]);
  }

  Widget _list(Map<int, TodayCheckIn> inToday) {
    switch (_filter) {
      case _Filter.inToday:
        final clients = widget.clientsOnly ? ref.watch(trainerDashboardProvider).value?.clients : null;
        final ids = clients?.map((c) => c.card.id).toSet();
        return _rows(inToday.values.map((c) => c.member).where((m) => ids == null || ids.contains(m.id)), inToday);
      case _Filter.ending || _Filter.expired:
        return AsyncView(
          value: ref.watch(followUpsProvider),
          onRetry: () => ref.invalidate(followUpsProvider),
          loading: const SkeletonList.inline(),
          data: (f) => _rows((_filter == _Filter.ending ? f.expiring : f.lapsed).map((r) => r.member), inToday),
        );
      case _Filter.all when widget.clientsOnly:
        return AsyncView(
          value: ref.watch(trainerDashboardProvider),
          onRetry: () => ref.invalidate(trainerDashboardProvider),
          loading: const SkeletonList.inline(),
          data: (d) => d.clients.isEmpty
              ? const StateMessage.empty(
                  title: 'No clients yet',
                  message: 'A manager assigns members to you on the web staff page.',
                )
              : _rows(_inFirst(d.clients.map((c) => c.card), inToday), inToday),
        );
      case _Filter.all:
        return _AllMembers(
          query: _query,
          pages: _pages,
          inToday: inToday,
          onMore: () => setState(() => _pages++),
        );
    }
  }

  /// With no search, the people who are in come first.
  Iterable<MemberCard> _inFirst(Iterable<MemberCard> members, Map<int, TodayCheckIn> inToday) => _query.isNotEmpty
      ? members
      : [...members.where((m) => inToday.containsKey(m.id)), ...members.where((m) => !inToday.containsKey(m.id))];
}

/// Every member, a page at a time from the server (which does the search).
class _AllMembers extends ConsumerWidget {
  const _AllMembers({required this.query, required this.pages, required this.inToday, required this.onMore});

  final String query;
  final int pages;
  final Map<int, TodayCheckIn> inToday;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = ref.watch(membersPageProvider((search: query, page: 1)));
    return AsyncView(
      value: first,
      onRetry: () => ref.invalidate(membersPageProvider((search: query, page: 1))),
      loading: const SkeletonList.inline(itemCount: 6),
      data: (page) {
        if (page.members.isEmpty) {
          return const StateMessage.empty(title: 'No match', message: 'Try part of the name, or the phone number.');
        }
        // With no search, today's check-ins first, then everyone else.
        final pinned = query.isEmpty ? inToday.values.map((c) => c.member).toList() : const <MemberCard>[];
        final skip = pinned.map((m) => m.id).toSet();
        return Column(children: [
          for (final m in pinned)
            MemberRow(member: m, inAt: inToday[m.id]?.at, inBy: inToday[m.id]?.method, onTap: () => showMemberSheet(context, m)),
          for (var i = 1; i <= pages; i++) _Page(search: query, page: i, skip: skip, inToday: inToday),
          if (pages < page.lastPage)
            Padding(
              padding: const EdgeInsets.all(AppGutter.cards),
              child: OutlinedButton(onPressed: onMore, child: const Text('Load more')),
            ),
        ]);
      },
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({required this.search, required this.page, required this.skip, required this.inToday});

  final String search;
  final int page;
  final Set<int> skip;
  final Map<int, TodayCheckIn> inToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(membersPageProvider((search: search, page: page)));
    return AsyncView(
      value: value,
      onRetry: () => ref.invalidate(membersPageProvider((search: search, page: page))),
      loading: const SkeletonList.inline(itemCount: 2),
      data: (p) => Column(children: [
        for (final m in p.members)
          if (!skip.contains(m.id))
            MemberRow(member: m, inAt: inToday[m.id]?.at, inBy: inToday[m.id]?.method, onTap: () => showMemberSheet(context, m)),
      ]),
    );
  }
}
