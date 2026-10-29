import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';

/// A short message at the top of the screen, with an optional action.
class ToastMessage {
  const ToastMessage(this.text, {this.actionLabel, this.onAction, this.hold = AppMotion.toastHold});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration hold;
}

/// The one toast on screen. It replaces SnackBar app-wide (design.md §3), so
/// screens, sheets and the notifications controller all post here.
class ToastController extends ChangeNotifier {
  ToastMessage? _current;
  Timer? _timer;

  ToastMessage? get current => _current;

  void show(String text, {String? actionLabel, VoidCallback? onAction, Duration hold = AppMotion.toastHold}) {
    _timer?.cancel();
    _current = ToastMessage(text, actionLabel: actionLabel, onAction: onAction, hold: hold);
    _timer = Timer(hold, clear);
    notifyListeners();
  }

  void clear() {
    _timer?.cancel();
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final toastProvider = Provider<ToastController>((ref) {
  final controller = ToastController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Posts a toast from anywhere under the ProviderScope.
void showToast(BuildContext context, String text) =>
    ProviderScope.containerOf(context, listen: false).read(toastProvider).show(text);

/// Shows the current toast over the whole app. Sits in MaterialApp.builder,
/// above the navigator, so it stays put while sheets and pages change.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(toastProvider);
    final duration = AppMotion.of(context, AppMotion.toast);
    return Stack(children: [
      child,
      Positioned(
        top: MediaQuery.paddingOf(context).top + AppSpace.md,
        left: AppGutter.cards,
        right: AppGutter.cards,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final message = controller.current;
            return AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: message == null
                  ? const SizedBox.shrink()
                  : _Toast(key: ValueKey(message), message: message, onAction: () {
                      controller.clear();
                      message.onAction?.call();
                    }),
            );
          },
        ),
      ),
    ]);
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.message, required this.onAction});

  final ToastMessage message;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13.5, color: p.background);
    return Center(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
            padding: EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, message.actionLabel == null ? AppSpace.xl : AppSpace.sm, AppSpace.sm),
            decoration: BoxDecoration(
              color: p.text,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.lg,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(message.text, style: style)),
              if (message.actionLabel != null) ...[
                const SizedBox(width: AppSpace.sm),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: p.inverseAccent),
                  onPressed: onAction,
                  child: Text(message.actionLabel!),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
