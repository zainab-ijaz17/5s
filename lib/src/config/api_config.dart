import 'package:flutter/foundation.dart';

/// Shared API base URL for 5S and Digital Gemba.
abstract final class ApiConfig {
  ApiConfig._();

  static const productionBaseUrl = 'https://5s-api.packagesgroup.com';

  /// Local Nest API (see `backend-nest` `PORT`, default 3000).
  static const localBaseUrl = 'http://localhost:3000';

  /// Set to `false` before shipping store builds to production API.
  static const useLocalBackend = true;

  /// Override with `--dart-define=API_BASE_URL=...` when needed.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    final trimmed = fromEnv.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.replaceFirst(RegExp(r'/+$'), '');
    }

    if (useLocalBackend || !kReleaseMode) {
      return localBaseUrl;
    }

    return productionBaseUrl;
  }
}
