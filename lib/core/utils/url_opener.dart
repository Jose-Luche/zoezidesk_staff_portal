import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app (the phone's browser or PDF viewer).
/// Returns false when nothing could open it. Overridable in tests.
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>(
  (_) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);
