/// Build-time configuration, supplied with
/// `--dart-define-from-file=env/<name>.json`. Nothing here is hardcoded.
///
/// Firebase (app notifications) is added once the app is registered in the
/// Firebase project; see README.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
