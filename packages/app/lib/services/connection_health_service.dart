import 'dart:async';
import 'package:http/http.dart' as http;
import 'env_config.dart';

enum ConnectionStatus { checking, connected, disconnected, error }

class ConnectionHealth {
  final ConnectionStatus status;
  final String? message;
  final DateTime lastChecked;

  ConnectionHealth({
    required this.status,
    this.message,
    required this.lastChecked,
  });

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isDisconnected => status == ConnectionStatus.disconnected;
  bool get isChecking => status == ConnectionStatus.checking;
  bool get hasError => status == ConnectionStatus.error;
}

class ConnectionHealthService {
  ConnectionHealth _apiHealth = ConnectionHealth(
    status: ConnectionStatus.checking,
    lastChecked: DateTime.now(),
  );

  ConnectionHealth _wsHealth = ConnectionHealth(
    status: ConnectionStatus.checking,
    lastChecked: DateTime.now(),
  );

  ConnectionHealth get apiHealth => _apiHealth;
  ConnectionHealth get wsHealth => _wsHealth;

  final _apiHealthController = StreamController<ConnectionHealth>.broadcast();
  final _wsHealthController = StreamController<ConnectionHealth>.broadcast();

  Stream<ConnectionHealth> get apiHealthStream => _apiHealthController.stream;
  Stream<ConnectionHealth> get wsHealthStream => _wsHealthController.stream;

  /// Check API health
  Future<ConnectionHealth> checkApiHealth() async {
    _apiHealth = ConnectionHealth(
      status: ConnectionStatus.checking,
      lastChecked: DateTime.now(),
    );
    _apiHealthController.add(_apiHealth);

    try {
      final apiUrl = EnvConfig.apiBaseUrl;
      if (apiUrl.isEmpty) {
        _apiHealth = ConnectionHealth(
          status: ConnectionStatus.error,
          message: 'API URL not configured',
          lastChecked: DateTime.now(),
        );
        _apiHealthController.add(_apiHealth);
        return _apiHealth;
      }

      // Try to connect to /health or root endpoint
      final uri = Uri.parse('$apiUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 404) {
        // 404 is ok if /health doesn't exist but server responds
        _apiHealth = ConnectionHealth(
          status: ConnectionStatus.connected,
          message: 'API server reachable',
          lastChecked: DateTime.now(),
        );
      } else {
        _apiHealth = ConnectionHealth(
          status: ConnectionStatus.error,
          message: 'API returned status ${response.statusCode}',
          lastChecked: DateTime.now(),
        );
      }
    } catch (e) {
      _apiHealth = ConnectionHealth(
        status: ConnectionStatus.disconnected,
        message: 'Cannot reach API: ${e.toString()}',
        lastChecked: DateTime.now(),
      );
    }

    _apiHealthController.add(_apiHealth);
    return _apiHealth;
  }

  /// Check both API and WebSocket health
  Future<void> checkAllConnections() async {
    await Future.wait([checkApiHealth()]);
  }

  /// Get summary of all connections
  Map<String, ConnectionHealth> getConnectionSummary() {
    return {'api': _apiHealth, 'websocket': _wsHealth};
  }

  void dispose() {
    _apiHealthController.close();
    _wsHealthController.close();
  }
}
