import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
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

/// A failure's message, for snackbars and inline errors.
String failureMessage(Object error) =>
    error is AppFailure ? error.message : 'Something went wrong. Please try again.';
