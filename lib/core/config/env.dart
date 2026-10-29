/// Build-time configuration, supplied with
/// `--dart-define-from-file=env/<name>.json`. Nothing here is hardcoded.
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  // The staff Android app in the members app's Firebase project, for
  // notifications. Without them the app runs without notifications.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
