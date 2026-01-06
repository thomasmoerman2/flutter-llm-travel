import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/chat_message.dart';
import '../env_config.dart';
import 'ai_service.dart';

/// WebSocket-based AI service for ChatGPT and Gemini
class WebSocketAIService implements AIService {
  final String model; // 'ChatGPT', 'Gemini', or 'Hybrid'
  WebSocketChannel? _channel;
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  Map<String, dynamic> _lastMetadata = {};
  String? _sessionId;

  // Timeout configuration (in seconds)
  static const int responseTimeout = 60; // 60 seconds for AI response

  WebSocketAIService(this.model, {String? sessionId}) : _sessionId = sessionId;

  @override
  String get modelName => model;

  /// Build WebSocket URL for the specific model
  String _buildWebSocketUrl() {
    final baseUrl = EnvConfig.wsBaseUrl;
    String endpoint;

    switch (model.toLowerCase()) {
      case 'chatgpt':
        endpoint = '/realtime/llm/chatgpt';
        break;
      case 'gemini':
        endpoint = '/realtime/llm/gemini';
        break;
      case 'hybrid':
        endpoint = '/realtime/llm/hybrid';
        break;
      default:
        endpoint = '/realtime/llm/chat'; // Use provider-agnostic endpoint
    }

    String url = '$baseUrl$endpoint';

    // Add sessionId as query parameter if provided
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      url += '?sessionId=$_sessionId';
    }

    return url;
  }

  @override
  Future<void> initialize() async {
    try {
      final wsUrl = _buildWebSocketUrl();
      debugPrint('🔌 Connecting to WebSocket: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      debugPrint('✅ WebSocket connected successfully');
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      throw AIServiceException(
        'Failed to connect to WebSocket server: ${e.toString()}',
        code: 'CONNECTION_ERROR',
        originalError: e,
      );
    }
  }

  /// Map model names to backend provider names
  String _getProviderName() {
    switch (model.toLowerCase()) {
      case 'chatgpt':
        return 'chatgpt';
      case 'gemini':
        return 'gemini';
      case 'hybrid':
        return 'hybrid';
      default:
        return 'chatgpt'; // Default to ChatGPT
    }
  }

  @override
  Stream<String> sendMessage(
    String message,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async* {
    if (_channel == null) {
      debugPrint('❌ WebSocket service not initialized');
      throw AIServiceException('Service not initialized');
    }

    String partialResponse = '';
    try {
      // Send message to WebSocket server in backend format
      // Note: Backend maintains conversation history via sessionId
      final request = {
        'prompt': message,
        'provider': _getProviderName(),
        'model': null, // Let backend use default model for provider
        'systemPrompt': 'You are a helpful travel assistant.',
        'sessionId': _sessionId,
      };

      debugPrint('📤 Sending WebSocket message: ${jsonEncode(request)}');
      _channel!.sink.add(jsonEncode(request));
      debugPrint('✅ Message sent to WebSocket');

      // Listen for response chunks with timeout
      final startTime = DateTime.now();
      await for (final data in _channel!.stream.timeout(
        Duration(seconds: responseTimeout),
        onTimeout: (sink) {
          debugPrint('⏱️ WebSocket response timeout after ${responseTimeout}s');
          debugPrint('📝 Partial response received before timeout:');
          debugPrint('Length: ${partialResponse.length} characters');
          if (partialResponse.isNotEmpty) {
            debugPrint('Content: ${partialResponse.substring(0, partialResponse.length > 200 ? 200 : partialResponse.length)}...');
          } else {
            debugPrint('Content: (empty - no response received)');
          }
          sink.close();
          throw AIServiceException(
            'Response timeout after ${responseTimeout} seconds. ${partialResponse.isNotEmpty ? "Partial response received (${partialResponse.length} chars)." : "No response received."}',
            code: 'TIMEOUT',
          );
        },
      )) {
        try {
          final response = jsonDecode(data as String);
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          debugPrint('⏱️ Response chunk received after ${elapsed}s');

          if (response['type'] == 'chunk') {
            // Yield text chunks for streaming display
            final content = response['content'] as String?;
            if (content != null && content.isNotEmpty) {
              partialResponse += content;
              // Update metadata with provider info
              _lastMetadata = {
                'provider': response['provider'],
                'sessionId': response['sessionId'],
              };
              yield content;
            }
          } else if (response['type'] == 'done') {
            // Stream complete
            debugPrint('✅ Response complete after ${elapsed}s (${partialResponse.length} chars)');
            break;
          } else if (response['type'] == 'error') {
            throw AIServiceException(
              response['error'] ?? 'Unknown error from server',
              code: 'SERVER_ERROR',
            );
          }
        } catch (e) {
          if (e is AIServiceException) rethrow;
          throw AIServiceException(
            'Failed to parse server response',
            originalError: e,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ WebSocket error: $e');
      if (e is AIServiceException) rethrow;
      throw AIServiceException(
        'Failed to send message: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      if (_channel == null) {
        await initialize();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> getResponseMetadata() {
    return {
      'model': model,
      'provider': 'websocket',
      ..._lastMetadata,
    };
  }

  @override
  Future<void> dispose() async {
    await _channel?.sink.close();
    await _responseController.close();
    _channel = null;
  }
}

/// Factory to create appropriate WebSocket AI service
class WebSocketAIServiceFactory {
  static AIService create(String model) {
    switch (model) {
      case 'ChatGPT':
      case 'Gemini':
        return WebSocketAIService(model);
      default:
        throw AIServiceException('Unsupported WebSocket model: $model');
    }
  }
}
