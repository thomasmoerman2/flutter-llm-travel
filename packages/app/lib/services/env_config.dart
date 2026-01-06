import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper class to access environment variables
class EnvConfig {
  // API Configuration
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:5189';

  // WebSocket Configuration
  static String get wsBaseUrl =>
      dotenv.env['WS_BASE_URL'] ?? 'ws://localhost:5189';

  // Third-party Services
  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // Environment
  static String get env => dotenv.env['ENV'] ?? 'production';
  static bool get isDebug => dotenv.env['DEBUG'] == 'true';
  static bool get isProduction => env == 'production';
  static bool get isDevelopment => env == 'development';

  // Check if a key exists
  static bool hasKey(String key) => dotenv.env.containsKey(key);

  // Get any environment variable
  static String? get(String key) => dotenv.env[key];

  // Get with default value
  static String getOrDefault(String key, String defaultValue) {
    return dotenv.env[key] ?? defaultValue;
  }
}
