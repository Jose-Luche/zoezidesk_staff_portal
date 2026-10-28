import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../data/models/staff.dart';
import '../../../data/repositories/auth_repository.dart';

sealed class SessionState {
  const SessionState({this.device});

  /// Set when this is the gym's front-desk device: signing out goes back to
  /// the lock screen instead of the email login.
  final FrontDeskDevice? device;
}

/// Reading the stored session at startup.
class SessionLoading extends SessionState {
  const SessionLoading();
}

class SignedOut extends SessionState {
  const SignedOut({this.reason, super.device});

  /// Shown on the login or lock screen, e.g. after the server ended the session.
  final String? reason;
}

class SignedIn extends SessionState {
  const SignedIn(this.staff, {super.device});

  final StaffProfile staff;
}

/// App-wide auth state. The router listens to it for its guards and to
/// build the tabs from the staff member's permissions.
class SessionController extends Notifier<SessionState> {
  bool _expiring = false;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  @override
  SessionState build() {
    _restore();
    return const SessionLoading();
  }

  Future<void> _restore() async {
    final stored = await _auth.restore();
    final staff = stored.staff;
    state = staff == null ? SignedOut(device: stored.device) : SignedIn(staff, device: stored.device);
    if (staff != null) refreshProfile();
  }

  void signedIn(StaffProfile staff) => state = SignedIn(staff, device: state.device);

  void enrolled(FrontDeskDevice device) => state = SignedOut(device: device);

  /// Roles change on the web; the token refresh and app resume bring them here.
  void updateProfile(StaffProfile staff) {
    if (state is SignedIn) state = SignedIn(staff, device: state.device);
  }

  Future<void> refreshProfile() async {
    try {
      updateProfile(await _auth.refreshProfile());
    } on AppFailure {
      // Offline: keep the stored profile. A 401 has already ended the session.
    }
  }

  /// Sign out, or lock a front-desk device for the next person.
  Future<void> signOut({String? reason}) async {
    final device = state.device;
    await _auth.signOut();
    state = SignedOut(device: device, reason: reason);
  }

  /// This phone stops being the front-desk device (it stays enrolled on the
  /// web until a manager revokes it there).
  Future<void> forgetDevice() async {
    await _auth.signOut();
    await _auth.forgetDevice();
    state = const SignedOut();
  }

  /// Called when an authenticated request returns 401. Several requests can
  /// fail together, so only the first one acts.
  Future<void> expire() async {
    if (_expiring || state is! SignedIn) return;
    _expiring = true;
    try {
      await _auth.discardSession();
      state = SignedOut(device: state.device, reason: 'Your session has ended. Please sign in again.');
    } finally {
      _expiring = false;
    }
  }
}

final sessionControllerProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in staff member. Only read inside the signed-in part of the app.
final staffProvider = Provider<StaffProfile>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session is! SignedIn) throw StateError('Not signed in');
  return session.staff;
});
