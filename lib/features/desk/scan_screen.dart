import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/member_tile.dart';
import '../auth/state/session_controller.dart';
import 'desk_providers.dart';
import 'offline_desk.dart';

/// Scan after scan: each code checks a member in and shows the result, then
/// the camera is ready for the next one.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  static const _showResultFor = Duration(seconds: 3);

  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  CheckInResult? _result;
  String? _error;

  /// Offline, and the code wasn't on the offline list: staff may still let
  /// the member in and record it.
  String? _unverifiedCode;
  bool _busy = false;
  String? _lastCode;
  Timer? _clear;

  @override
  void dispose() {
    _clear?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue;
    // One scan at a time, and not the same code again while its result shows.
    if (code == null || _busy || code == _lastCode) return;
    setState(() {
      _busy = true;
      _lastCode = code;
    });
    try {
      final result = await ref.read(staffApiProvider).checkIn(qrCode: code);
      memberDataChanged(ref);
      result.success ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
      setState(() {
        _result = result;
        _error = null;
        _unverifiedCode = null;
      });
      // Back online: send anything checked in while it was down.
      if (ref.exists(offlineDeskProvider)) ref.read(offlineDeskProvider.notifier).send();
    } catch (e) {
      final offline = e is NetworkFailure || e is TimeoutFailure;
      if (offline && ref.exists(offlineDeskProvider)) {
        await _checkInOffline(code);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _result = null;
          _error = failureMessage(e);
          _unverifiedCode = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _clear?.cancel();
    _clear = Timer(_showResultFor, () {
      if (mounted) setState(() => _lastCode = null);
    });
  }

  Future<void> _checkInOffline(String code) async {
    final desk = ref.read(offlineDeskProvider.notifier);
    final member = desk.match(code);
    if (member != null) {
      await desk.record(code, name: member.name);
      HapticFeedback.mediumImpact();
      setState(() {
        _result = CheckInResult(
          success: true,
          duplicate: false,
          message: 'Welcome, ${member.name}! Saved offline; it will be sent when the connection is back.',
          member: member,
        );
        _error = null;
        _unverifiedCode = null;
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _result = null;
        _error = "You're offline and this code isn't on the saved member list (no current membership, "
            'or they joined since it was saved).';
        _unverifiedCode = code;
      });
    }
  }

  Future<void> _letInAnyway() async {
    final code = _unverifiedCode;
    if (code == null) return;
    await ref.read(offlineDeskProvider.notifier).record(code);
    if (!mounted) return;
    setState(() {
      _error = null;
      _unverifiedCode = null;
      _result = const CheckInResult(
        success: true,
        duplicate: false,
        message: 'Recorded offline. The server will check the membership when it is sent.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final p = context.palette;
    final result = _result;
    final ok = result?.success ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to check in'),
        actions: [
          IconButton(tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_rounded), onPressed: _camera.toggleTorch),
          IconButton(tooltip: 'Switch camera', icon: const Icon(Icons.cameraswitch_rounded), onPressed: _camera.switchCamera),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Allow camera access in the phone\'s settings to scan QR codes.'
                        : 'The camera could not start.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: AppMotion.fast,
            width: double.infinity,
            color: result == null && _error == null ? p.surface : (ok ? p.success : p.danger).withValues(alpha: 0.15),
            padding: const EdgeInsets.all(AppSpace.md),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (result == null && _error == null && !_busy)
                    Text('Point the camera at the member\'s QR code.', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium),
                  if (_error != null) _Outcome(ok: false, message: _error!),
                  if (_unverifiedCode != null)
                    OutlinedButton.icon(
                      onPressed: _letInAnyway,
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: const Text('Let in and record'),
                    ),
                  if (result != null) ...[
                    _Outcome(ok: ok, message: result.message),
                    if (result.member != null) MemberTile(member: result.member!),
                    if (!ok && result.member != null && staff.can('payments.record'))
                      FilledButton.icon(
                        onPressed: () => context.push(Routes.pay(result.member!.id)),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Take payment'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.ok, required this.message});

  final bool ok;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: ok ? p.success : p.danger, size: AppSpace.xl),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.titleLarge)),
        ],
      ),
    );
  }
}
