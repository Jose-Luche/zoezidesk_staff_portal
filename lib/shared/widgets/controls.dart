import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';

/// Equal-width options in a pill track with a divider border. The selected
/// one fills with text color, or accent for report periods.
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.accent = false,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fill = accent ? p.accent : p.text;
    final onFill = accent ? p.onAccent : p.background;
    final duration = AppMotion.of(context, AppMotion.fast);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: p.divider),
      ),
      child: Row(children: [
        for (final (value, label) in options)
          Expanded(
            child: Semantics(
              selected: value == selected,
              button: true,
              inMutuallyExclusiveGroup: true,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: duration,
                  height: AppSizes.minTouch,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? fill : Organic.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: value == selected ? onFill : p.text),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A filter or type chip. Off: outlined. On: text fill (filters) or the
/// strong sage (note types).
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, required this.selected, required this.onTap, this.sage = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool sage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fill = sage ? p.sageStrong : p.text;
    final onFill = sage ? p.onSageStrong : p.background;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Organic.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? fill : Organic.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: selected ? fill : p.divider),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 12.5,
                        color: selected ? onFill : p.text,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of [PillChip]s that scrolls sideways when it doesn't fit.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: AppGutter.cards)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: AppSpace.sm), c],
        ]),
      );
}

/// Which Home to show, for people who hold more than one role.
class RoleSwitcher<T> extends StatelessWidget {
  const RoleSwitcher({super.key, required this.options, required this.selected, required this.onChanged});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.neutral.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.sm,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (value, label) in options)
          Semantics(
            selected: value == selected,
            button: true,
            inMutuallyExclusiveGroup: true,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(value);
              },
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                constraints: const BoxConstraints(minHeight: 38),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: value == selected ? p.text : Organic.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: value == selected ? p.background : p.neutral.on,
                      ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A pill radio row (plans): name, a muted detail, and a figure on the right.
class RadioPillRow extends StatelessWidget {
  const RadioPillRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
    this.trailing,
  });

  final String title;
  final String? detail;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? p.warning.fill : p.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? p.accent : Organic.transparent, width: 2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
            child: Row(children: [
              // A ring with the dot inset 4 px from it when selected.
              AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? p.accent : p.track, width: selected ? 2 : 1.5),
                ),
                child: selected
                    ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: p.accent))
                    : null,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: title, style: text.titleSmall),
                    if (detail != null && detail!.isNotEmpty)
                      TextSpan(text: ' · $detail', style: text.bodyMedium?.copyWith(color: p.muted)),
                  ]),
                ),
              ),
              if (trailing != null) Text(trailing!, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The 44 px round tick on a class roster.
class CheckToggle extends StatelessWidget {
  const CheckToggle({super.key, required this.value, required this.onChanged, required this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: value,
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          width: AppSizes.checkToggle,
          height: AppSizes.checkToggle,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? Organic.sage600 : Organic.transparent,
            border: value ? null : Border.all(color: p.track, width: 1.5),
          ),
          child: value ? const Icon(AppIcons.check, size: AppIconSize.md, color: Organic.n100) : null,
        ),
      ),
    );
  }
}

/// A switch with its label, full width (the WhatsApp confirmation).
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.bodyLarge),
                if (subtitle != null) Text(subtitle!, style: text.bodySmall),
              ]),
            ),
            const SizedBox(width: AppSpace.md),
            Transform.scale(
              // Material's switch is 52 × 32; the design's is 46 × 28.
              scale: 0.88,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A pill input with its label above and helper or error below.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.error,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofocus = false,
    this.autofillHints,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? error;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  bool get _multiline => (maxLines ?? 2) > 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    InputBorder? area(Color color, [double width = 1]) => _multiline
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: BorderSide(color: color, width: width),
          )
        : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(left: AppSpace.sm, bottom: 6),
        child: Text(label, style: theme.textTheme.labelMedium?.copyWith(fontSize: 12, color: p.neutral.on)),
      ),
      TextFormField(
        controller: controller,
        keyboardType: _multiline ? TextInputType.multiline : keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        autofocus: autofocus,
        autofillHints: autofillHints,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          helperText: helper,
          errorText: error,
          prefixIcon: prefixIcon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.sm),
                  child: Icon(prefixIcon, size: AppIconSize.md),
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: AppSizes.minTouch, minHeight: AppSizes.minTouch),
          suffixIcon: suffix,
          contentPadding: _multiline ? const EdgeInsets.all(18) : null,
          border: area(p.divider),
          enabledBorder: area(p.divider),
          focusedBorder: area(p.accent, 2),
          errorBorder: area(p.danger.on),
          focusedErrorBorder: area(p.danger.on, 2),
        ),
      ),
    ]);
  }
}
