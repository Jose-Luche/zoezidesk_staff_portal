import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/read_cache.dart';
import 'skeleton.dart';
import 'state_message.dart';

/// Loading, error and data for a provider, with the designed states: a
/// skeleton while loading, offline or error with Try again.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, required this.onRetry, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    // While refreshing, keep showing what is already there.
    if (value.hasValue && !value.hasError) return data(value.requireValue);
    // A refresh failed: still what is already there, with a note that it
    // may be out of date.
    if (value.hasValue) {
      return _Stale(notice: StaleNotice(error: value.error!, onRetry: onRetry), child: data(value.requireValue));
    }
    if (value.hasError) {
      return switch (value.error) {
        NetworkFailure() => StateMessage.offline(onAction: onRetry),
        AppFailure(:final message) => StateMessage.error(message: message, onAction: onRetry),
        _ => StateMessage.error(onAction: onRetry),
      };
    }
    return loading ?? const SkeletonList();
  }
}

/// The notice above the data: full height when the view fills the screen,
/// shrink-wrapped when it sits in a list.
class _Stale extends StatelessWidget {
  const _Stale({required this.notice, required this.child});

  final Widget notice;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => constraints.hasBoundedHeight
            ? Column(children: [notice, Expanded(child: child)])
            : Column(mainAxisSize: MainAxisSize.min, children: [notice, child]),
      );
}

/// "Offline · updated 5 min ago", with Try again. Data saved more than a
/// day ago is called out as possibly out of date.
class StaleNotice extends StatelessWidget {
  const StaleNotice({super.key, required this.error, required this.onRetry});

  static const oldAfter = Duration(hours: 24);

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final (cause, savedAt) = switch (error) {
      OutOfDate(:final cause, :final savedAt) => (cause, savedAt),
      _ => (error, null),
    };
    final offline = cause is NetworkFailure;
    final now = DateTime.now();
    final old = savedAt != null && now.difference(savedAt) > oldAfter;
    final when = savedAt == null ? 'showing what was loaded earlier' : 'updated ${formatRelative(savedAt, now)}';
    final message = old
        ? 'Last updated ${formatRelative(savedAt, now)} · may be out of date'
        : offline
            ? 'Offline · $when'
            : "Couldn't refresh · $when";
    final color = old ? p.warning.on : p.muted;

    return Container(
      color: old ? p.warning.fill : null,
      padding: const EdgeInsets.fromLTRB(AppGutter.heading, AppSpace.xs, AppSpace.sm, AppSpace.xs),
      child: Row(children: [
        Icon(old ? AppIcons.clock : (offline ? AppIcons.offline : AppIcons.error), size: AppIconSize.sm, color: color),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(message, style: text.bodySmall?.copyWith(color: color))),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ]),
    );
  }
}

/// A failure's message, for snackbars and inline errors.
String failureMessage(Object error) =>
    error is AppFailure ? error.message : 'Something went wrong. Please try again.';
