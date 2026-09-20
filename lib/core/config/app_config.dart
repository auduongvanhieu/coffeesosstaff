/// Build-time configuration. Override with `--dart-define`, e.g.
/// `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1`
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev.coffeesos.online/api/v1',
  );

  /// WebSocket endpoint served by the Go backend at `/ws`.
  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://dev.coffeesos.online/api/ws',
  );

  static const appName = 'CoffeeSOS Staff';
}
