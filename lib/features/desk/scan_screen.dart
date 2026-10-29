import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/member_tile.dart';
import '../auth/state/session_controller.dart';
import '../payments/pay_sheet.dart';
import 'desk_providers.dart';
import 'offline_desk.dart';

/// What the last scan came to, which colors the frame and the card.
enum _Outcome { idle, welcome, ending, already, refused, unknown }

class _Result {
  const _Result(this.outcome, this.title, this.subtitle, {this.member, this.action});

  static const idle = _Result(_Outcome.idle, 'Ready', "Point the camera at the member's QR code.");

  final _Outcome outcome;
  final String title;
  final String subtitle;
  final MemberCard? member;

  /// The one button the card offers, if any.
  final ({String label, Future<void> Function() run})? action;
}

/// Scan after scan: each code checks a member in and the result stays on
/// the card until the next one, so the camera is always ready.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  /// The same code is ignored for this long, so one wave isn't two scans.
  static const _sameCodeFor = Duration(seconds: 3);

  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  _Result _result = _Result.idle;
  bool _busy = false;
  String? _lastCode;
  Timer? _forget;

  @override
  void dispose() {
    _forget?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || _busy || code == _lastCode) return;
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    // Before the check-in, so "already in" can say when they came.
    final earlier = ref.read(todayCheckInsProvider).value?.checkIns ?? const <TodayCheckIn>[];
    try {
      final result = await ref.read(staffApiProvider).checkIn(qrCode: code);
      memberDataChanged(ref);
      result.success && !result.duplicate ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
      _show(_fromServer(result, earlier));
      // Back online: send anything checked in while it was down.
      if (ref.exists(offlineDeskProvider)) ref.read(offlineDeskProvider.notifier).send();
    } catch (e) {
      final offline = e is NetworkFailure || e is TimeoutFailure;
      if (offline && ref.exists(offlineDeskProvider)) {
        await _checkInOffline(code);
      } else {
        HapticFeedback.heavyImpact();
        _show(_Result(_Outcome.refused, "Couldn't check in", failureMessage(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _forget?.cancel();
    _forget = Timer(_sameCodeFor, () {
      if (mounted) setState(() => _lastCode = null);
    });
  }

  void _show(_Result result) {
    if (mounted) setState(() => _result = result);
  }

  _Result _fromServer(CheckInResult r, List<TodayCheckIn> earlier) {
    final member = r.member;
    final first = firstName(member?.name);
    final m = member?.membership;
    if (r.duplicate) {
      final at = earlier.where((c) => c.member.id == member?.id).firstOrNull?.at;
      return _Result(
        _Outcome.already,
        '$first is already in',
        '${at == null ? 'Checked in earlier today' : 'Checked in at ${formatTime(at)}'}. Not counted twice.',
        member: member,
      );
    }
    if (r.success) {
      if (m != null && m.daysLeft <= 7) {
        return _Result(
          _Outcome.ending,
          'Welcome, $first',
          '${m.plan ?? 'Membership'} ends ${formatShortDate(m.expiresAt)}, so offer a renewal',
          member: member,
          action: _payAction(member!, 'Renew now'),
        );
      }
      return _Result(
        _Outcome.welcome,
        'Welcome, $first',
        m == null ? r.message : '${m.plan ?? 'Membership'} · until ${formatShortDate(m.expiresAt)}',
        member: member,
      );
    }
    if (member == null) return _Result(_Outcome.refused, 'Not let in', r.message);
    final ended = m == null
        ? 'No plan yet'
        : m.daysLeft < 0
            ? '${m.plan ?? 'Membership'} ended ${-m.daysLeft} day${m.daysLeft == -1 ? '' : 's'} ago'
            : r.message;
    return _Result(_Outcome.refused, member.name, ended, member: member, action: _payAction(member, 'Take payment to let in'));
  }

  ({String label, Future<void> Function() run})? _payAction(MemberCard member, String label) {
    if (!ref.read(staffProvider).can('payments.record')) return null;
    return (
      label: label,
      run: () async {
        final outcome = await showPaySheet(context, memberId: member.id);
        if (outcome == null || !mounted) return;
        // Paid from here: they're in, and the card says so.
        final first = firstName(member.name);
        _show(outcome.checkedIn
            ? _Result(_Outcome.welcome, 'Welcome, $first', '${outcome.payment.plan ?? 'Membership'} paid and checked in',
                member: member)
            : _Result(_Outcome.welcome, 'Paid, $first', 'Membership active. Check them in from the member sheet.',
                member: member));
      },
    );
  }

  Future<void> _checkInOffline(String code) async {
    final desk = ref.read(offlineDeskProvider.notifier);
    final member = desk.match(code);
    if (member != null) {
      await desk.record(code, name: member.name);
      HapticFeedback.mediumImpact();
      _show(_Result(_Outcome.welcome, 'Welcome, ${firstName(member.name)}',
          'Saved offline; it is sent when the connection is back.', member: member));
    } else {
      HapticFeedback.heavyImpact();
      _show(_Result(
        _Outcome.unknown,
        'Not on the saved list',
        "You're offline and this code isn't on the saved member list.",
        action: (label: 'Let in and record', run: () => _letInAnyway(code)),
      ));
    }
  }

  Future<void> _letInAnyway(String code) async {
    await ref.read(offlineDeskProvider.notifier).record(code);
    _show(const _Result(_Outcome.welcome, 'Recorded offline',
        'The server checks the membership when it is sent.'));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = switch (_result.outcome) {
      _Outcome.idle => Organic.n300,
      _Outcome.welcome || _Outcome.ending => Organic.sage400,
      _Outcome.already => Organic.n500,
      _Outcome.refused || _Outcome.unknown => Organic.accent,
    };
    final onDark = Organic.n100;

    return Scaffold(
      backgroundColor: Organic.n900,
      body: Column(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xxl),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? "Allow camera access in the phone's settings to scan QR codes."
                        : 'The camera could not start.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: onDark),
                  ),
                ),
              ),
            ),
            _ScanFrame(color: frame),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGutter.cards, vertical: AppSpace.sm),
                child: Row(children: [
                  CircleIconButton(
                    icon: AppIcons.close,
                    tooltip: 'Close',
                    fill: Organic.n300.withValues(alpha: 0.16),
                    color: onDark,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text('Scan to check in',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: onDark)),
                  ),
                  CircleIconButton(
                    icon: AppIcons.torch,
                    tooltip: 'Torch',
                    fill: Organic.n300.withValues(alpha: 0.16),
                    color: onDark,
                    onPressed: _camera.toggleTorch,
                  ),
                  const SizedBox(width: AppSpace.sm),
                  CircleIconButton(
                    icon: AppIcons.switchCamera,
                    tooltip: 'Switch camera',
                    fill: Organic.n300.withValues(alpha: 0.16),
                    color: onDark,
                    onPressed: _camera.switchCamera,
                  ),
                ]),
              ),
            ),
          ]),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 300),
          width: double.infinity,
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          padding: const EdgeInsets.fromLTRB(AppGutter.cards, AppSpace.xl, AppGutter.cards, AppSpace.lg),
          child: SafeArea(
            top: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_busy) const LinearProgressIndicator(minHeight: 3) else const SizedBox(height: 3),
              const SizedBox(height: AppSpace.md),
              _ResultCard(result: _result),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A 200 px rounded window with a 35% scrim outside it, edged in the color
/// of the last result.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.color});

  final Color color;

  static const _size = 200.0;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: _ScrimPainter(size: _size)),
          Center(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(44),
                border: Border.all(color: color, width: 4),
              ),
            ),
          ),
        ]),
      );
}

/// Darkens everything but the window.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size area) {
    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(center: area.center(Offset.zero), width: size, height: size),
      const Radius.circular(44),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & area)
      ..addRRect(window);
    canvas.drawPath(path, Paint()..color = Organic.n900.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.size != size;
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.result});

  final _Result result;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final r = widget.result;
    final tint = switch (r.outcome) {
      _Outcome.idle || _Outcome.already => Tint(p.surface, p.text),
      _Outcome.welcome || _Outcome.ending => p.success,
      _Outcome.refused => p.danger,
      _Outcome.unknown => p.warning,
    };
    final action = r.action;
    final member = r.member;

    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(color: tint.fill, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (member != null) ...[
              MemberAvatar(initials: member.initials, photoUrl: member.photoUrl, seed: member.id, size: 60),
              const SizedBox(width: AppSpace.lg),
            ] else ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: p.background.withValues(alpha: 0.7), shape: BoxShape.circle),
                child: Icon(
                  switch (r.outcome) {
                    _Outcome.idle => AppIcons.scan,
                    _Outcome.welcome || _Outcome.ending || _Outcome.already => AppIcons.success,
                    _Outcome.refused || _Outcome.unknown => AppIcons.refused,
                  },
                  color: tint.on,
                ),
              ),
              const SizedBox(width: AppSpace.lg),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title, style: text.titleLarge?.copyWith(color: tint.on)),
                const SizedBox(height: AppSpace.xs),
                Text(r.subtitle, style: text.bodyMedium?.copyWith(color: tint.on)),
              ]),
            ),
          ]),
          if (action != null) ...[
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _running
                  ? null
                  : () async {
                      setState(() => _running = true);
                      try {
                        await action.run();
                      } finally {
                        if (mounted) setState(() => _running = false);
                      }
                    },
              child: Text(action.label),
            ),
          ],
        ]),
      ),
    );
  }
}
