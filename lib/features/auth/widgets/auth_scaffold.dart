import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/cards.dart';

/// Shared layout for the sign-in steps: the corner circle, the wordmark, a
/// big flush-left title, a line under it, then the form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(children: [
        const CornerDecoration(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.lg, AppGutter.heading, AppSpace.xxxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    if (showBack) ...[
                      CircleIconButton(
                        icon: AppIcons.back,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpace.md),
                    ],
                    const BrandMark(),
                  ]),
                  const SizedBox(height: AppSpace.xxxl + AppSpace.lg),
                  Semantics(header: true, child: Text(title, style: text.displayLarge)),
                  const SizedBox(height: AppSpace.md),
                  Text(subtitle, style: text.bodyMedium?.copyWith(color: context.palette.muted)),
                  const SizedBox(height: AppSpace.xxl),
                  child,
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The ZoeziDesk wordmark in the Organic colors: terracotta and warm black
/// on cream, sand and light terracotta on dark. The original brand-orange
/// files stay next to them in assets/logo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  static const darkAsset = 'assets/logo/zoezi-desk-horizontal-organic-dark.svg';
  static const lightAsset = 'assets/logo/zoezi-desk-horizontal-organic-light.svg';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(dark ? darkAsset : lightAsset, height: 28, semanticsLabel: 'ZoeziDesk');
  }
}
