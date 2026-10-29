import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/storage/device_preferences.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/state_message.dart';
import '../auth/state/session_controller.dart';
import 'desk_home.dart';
import 'owner_home.dart';
import 'training_home.dart';

/// The Home this person last picked, remembered per staff member on this
/// phone. Null until they pick one (or while it loads).
final homeChoiceProvider = NotifierProvider.autoDispose<HomeChoice, HomeVariant?>(HomeChoice.new);

class HomeChoice extends Notifier<HomeVariant?> {
  @override
  HomeVariant? build() {
    final staffId = ref.watch(staffProvider).id;
    Future.microtask(() async {
      final saved = await ref.read(devicePreferencesProvider).readHome(staffId);
      final match = HomeVariant.values.where((v) => v.name == saved).firstOrNull;
      if (ref.mounted && state == null && match != null) state = match;
    });
    return null;
  }

  void pick(HomeVariant variant) {
    state = variant;
    ref.read(devicePreferencesProvider).writeHome(ref.read(staffProvider).id, variant.name);
  }
}

/// One Home, shaped by role (design.md §4): what this person must act on
/// now. People with more than one role switch at the top.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    final variants = homeVariantsFor(staff);
    final chosen = ref.watch(homeChoiceProvider);
    final variant = variants.contains(chosen) ? chosen : defaultHomeVariant(variants);

    final header = HomeHeader(
      switcher: variants.length < 2
          ? null
          : RoleSwitcher<HomeVariant>(
              options: [for (final v in variants) (v, v.label)],
              selected: variant!,
              onChanged: ref.read(homeChoiceProvider.notifier).pick,
            ),
    );

    return Scaffold(
      body: Stack(children: [
        const CornerDecoration(),
        SafeArea(
          bottom: false,
          child: switch (variant) {
            HomeVariant.desk => DeskHome(header: header),
            HomeVariant.training => TrainingHome(header: header),
            HomeVariant.owner => OwnerHome(header: header),
            null => ListView(children: [
                header,
                Greeting(title: '${partOfDay(DateTime.now())},\n${firstName(staff.name)}.'),
                const StateMessage.empty(
                  title: 'Nothing here yet',
                  message: 'Your role has no front-desk, training or report work in the app. Ask a manager if that seems wrong.',
                ),
              ]),
          },
        ),
      ]),
    );
  }
}

/// The row above every Home: the role switcher, and the avatar that opens
/// More (shift, follow-ups, enquiries, PIN, settings).
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.switcher});

  final Widget? switcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGutter.cards, AppSpace.md, AppGutter.cards, 0),
      child: Row(children: [
        if (switcher != null) Flexible(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: switcher)),
        const Spacer(),
        Semantics(
          button: true,
          label: 'More: shift, follow-ups, PIN and settings',
          excludeSemantics: true,
          child: Tooltip(
            message: 'More',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(Routes.more),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: MemberAvatar(initials: initialsOf(staff.name), seed: staff.id, size: 44),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The big flush-left greeting and the line under it.
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.title, this.subtitle, this.large = true});

  final String title;
  final String? subtitle;

  /// Display large for people; display medium for the gym's name.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.xxl, AppGutter.heading, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(title, style: large ? text.displayLarge : text.displayMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(subtitle!, style: text.bodyMedium?.copyWith(color: context.palette.muted)),
        ],
      ]),
    );
  }
}
