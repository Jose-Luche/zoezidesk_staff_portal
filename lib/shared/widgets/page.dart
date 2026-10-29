import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import 'buttons.dart';

/// A pushed page: a round Back button, a flush-left Caprasimo title and the
/// body. Tabs draw their own headlines instead.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.title, required this.body, this.actions = const [], this.floatingActionButton});

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        titleSpacing: canPop ? AppSpace.md : AppGutter.heading,
        leadingWidth: canPop ? AppGutter.cards + AppSizes.minTouch : 0,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: AppGutter.cards),
                child: Center(
                  child: CircleIconButton(
                    icon: AppIcons.back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              )
            : null,
        title: Text(title),
        actions: [...actions, const SizedBox(width: AppSpace.sm)],
      ),
      body: body,
    );
  }
}

/// A tab's big flush-left headline with an optional action beside it.
class TabHeadline extends StatelessWidget {
  const TabHeadline(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.lg, AppGutter.cards, AppSpace.lg),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineLarge)),
          ),
          ?action,
        ]),
      );
}
