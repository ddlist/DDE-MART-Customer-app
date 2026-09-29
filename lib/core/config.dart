// DDE-Mart customer app — static config (original).
//
// The API host is injected at build/run time so the same binary recipe works
// for local, staging and production:
//
//   flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://dde-mart-admin.test/api/v1',
  );

  /// Audience checked against GET /app-config min_versions.
  static const audience = 'customer';

  static const appName = 'DDE-Mart';
}
