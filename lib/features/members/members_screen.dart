import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
import 'member_providers.dart';

/// Every member of the gym (owners, managers, receptionists).
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _pages = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() {
          _query = value.trim().length >= 2 ? value.trim() : '';
          _pages = 1;
        }));
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final first = ref.watch(membersPageProvider((search: _query, page: 1)));

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: staff.can('members.create')
          ? FloatingActionButton(
              tooltip: 'Register a member',
              onPressed: () => context.push(Routes.newMember),
              child: const Icon(Icons.person_add_alt_1_rounded),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Search name, phone, number or email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _pages = 1);
                ref.invalidate(membersPageProvider);
              },
              child: AsyncView(
                value: first,
                onRetry: () => ref.invalidate(membersPageProvider((search: _query, page: 1))),
                data: (page) {
                  if (page.members.isEmpty) {
                    return const StateMessage.empty(title: 'No members found', message: 'Try another search.');
                  }
                  return ListView.builder(
                    itemCount: _pages + 1,
                    itemBuilder: (context, i) {
                      if (i == _pages) {
                        return _pages < page.lastPage
                            ? Padding(
                                padding: const EdgeInsets.all(AppSpace.md),
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _pages++),
                                  child: const Text('Load more'),
                                ),
                              )
                            : const SizedBox(height: AppSpace.xxxl);
                      }
                      return _Page(search: _query, page: i + 1);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({required this.search, required this.page});

  final String search;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(membersPageProvider((search: search, page: page)));
    return AsyncView(
      value: value,
      onRetry: () => ref.invalidate(membersPageProvider((search: search, page: page))),
      loading: const Padding(padding: EdgeInsets.all(AppSpace.md), child: LinearProgressIndicator()),
      data: (p) => Column(children: [
        for (final m in p.members) MemberTile(member: m, onTap: () => context.push(Routes.member(m.id))),
      ]),
    );
  }
}
