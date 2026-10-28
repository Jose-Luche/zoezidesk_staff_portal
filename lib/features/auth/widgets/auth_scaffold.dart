import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_tokens.dart';

/// Shared layout for the login steps: brand mark, title, subtitle, form.
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
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandMark(),
                  const SizedBox(height: AppSpace.xl),
                  Text(title, style: text.headlineLarge),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    subtitle,
                    style: text.bodyMedium?.copyWith(color: context.palette.textMuted),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ZoeziDesk wordmark, light text on dark and navy text on light.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  static const darkAsset = 'assets/logo/zoezi-desk-horizontal-dark.svg';
  static const lightAsset = 'assets/logo/zoezi-desk-horizontal-light.svg';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: SvgPicture.asset(
        dark ? darkAsset : lightAsset,
        height: AppSpace.xl,
        semanticsLabel: 'ZoeziDesk',
      ),
    );
  }
}

/// Inline error under a form, with an icon so it does not rely on color.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final danger = context.palette.danger;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: danger, size: AppSizes.icon),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: danger),
            ),
          ),
        ],
      ),
    );
  }
}
