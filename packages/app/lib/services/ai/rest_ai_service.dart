import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/chat_message.dart';
import '../env_config.dart';
import 'ai_service.dart';

/// REST-based AI service for ChatGPT, Gemini, and Hybrid
class RestAIService implements AIService {
  final String model; // 'ChatGPT', 'Gemini', or 'Hybrid'
  String? _sessionId;
  Map<String, dynamic> _lastMetadata = {};

  // Timeout configuration (in seconds)
  static const int responseTimeout = 60;

  RestAIService(this.model, {String? sessionId}) : _sessionId = sessionId;

  @override
  String get modelName => model;

  /// Build REST API URL for the specific model
  String _buildApiUrl() {
    // Convert ws://localhost:5189 to http://localhost:5189
    final baseUrl = EnvConfig.wsBaseUrl.replaceFirst('ws://', 'http://');
    String endpoint;

    switch (model.toLowerCase()) {
      case 'chatgpt':
        endpoint = '/api/ai/chatgpt';
        break;
      case 'gemini':
        endpoint = '/api/ai/gemini';
        break;
      case 'hybrid':
        endpoint = '/api/ai/hybrid';
        break;
      default:
        endpoint = '/api/ai/chatgpt'; // Default to ChatGPT
    }

    return '$baseUrl$endpoint';
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
        return 'chatgpt';
    }
  }

  @override
  Future<void> initialize() async {
    // No initialization needed for REST API
    debugPrint('✅ REST AI service initialized for $model');
  }

  @override
  Stream<String> sendMessage(
    String message,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async* {
    final startTime = DateTime.now();

    try {
      final apiUrl = _buildApiUrl();

      // Build conversation context from history
      final contextMessages = conversationHistory
          .map((msg) => '${msg.isUser ? "User" : "Assistant"}: ${msg.content}')
          .join('\n');

      // Build system prompt with context and location instructions
      final basePrompt = '''You are a helpful travel assistant.

CRITICAL: When providing travel recommendations with specific locations (landmarks, museums, restaurants, parks, etc.), you MUST include location data at the end of your response in this EXACT JSON format:

```json
{
  "locations": [
    {"name": "Location Name", "lat": 0.0, "lng": 0.0, "description": "Brief description"}
  ]
}
```

IMPORTANT RULES:
1. Include a JSON block for EVERY place you recommend (not just one)
2. Each location MUST have accurate, real GPS coordinates (latitude/longitude)
3. DO NOT use placeholder coordinates like 0.0, 0.0
4. Each location must have DIFFERENT coordinates (the actual location of that place)
5. The "description" field is optional but helpful
6. If the user asks for a route/directions, add: "route": {"type": "walking"} (or "driving", "cycling")

EXAMPLE (notice MULTIPLE locations with DIFFERENT coordinates):
"Amsterdam has amazing attractions! Here are my top picks:

1. **Anne Frank House** - A moving historical museum
2. **Rijksmuseum** - Home to Dutch masterpieces
3. **Van Gogh Museum** - Dedicated to Van Gogh's works
4. **Vondelpark** - Beautiful urban park

```json
{
  "locations": [
    {"name": "Anne Frank House", "lat": 52.3752, "lng": 4.8840, "description": "Historical museum"},
    {"name": "Rijksmuseum", "lat": 52.3600, "lng": 4.8852, "description": "Dutch art museum"},
    {"name": "Van Gogh Museum", "lat": 52.3584, "lng": 4.8811, "description": "Van Gogh collection"},
    {"name": "Vondelpark", "lat": 52.3579, "lng": 4.8686, "description": "Urban park"}
  ]
}
```"

Remember: Include ALL locations you mention with their REAL coordinates!
''';

      final systemPrompt = contextMessages.isEmpty
          ? basePrompt
          : '$basePrompt\n\nConversation history:\n$contextMessages';

      // Prepare request body matching backend API
      final requestBody = {
        'prompt': message,
        'model': null, // Let backend use default model for provider
        'systemPrompt': systemPrompt,
        'sessionId': _sessionId,
      };

      debugPrint('📤 Sending REST request to: $apiUrl');
      debugPrint('📝 Request body: ${jsonEncode(requestBody)}');

      // Send POST request with timeout
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            Duration(seconds: responseTimeout),
            onTimeout: () {
              debugPrint('⏱️ REST request timeout after ${responseTimeout}s');
              throw AIServiceException(
                'Response timeout after $responseTimeout seconds. Please try again.',
                code: 'TIMEOUT',
              );
            },
          );

      final elapsed = DateTime.now().difference(startTime).inSeconds;
      debugPrint('⏱️ Response received after ${elapsed}s');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        // Update metadata
        _lastMetadata = {
          'provider': responseData['provider'],
          'sessionId': responseData['sessionId'],
        };

        // Update session ID from response
        _sessionId = responseData['sessionId'] as String?;

        final content = responseData['content'] as String? ?? '';
        debugPrint('✅ Response complete (${content.length} chars)');

        // Yield the complete response at once
        yield content;
      } else {
        debugPrint('❌ REST request failed with status ${response.statusCode}');
        debugPrint('Response body: ${response.body}');

        throw AIServiceException(
          'Server error: ${response.statusCode} - ${response.reasonPhrase}',
          code: 'SERVER_ERROR',
        );
      }
    } catch (e) {
      debugPrint('❌ REST API error: $e');
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
      // Could ping a health endpoint, but for now just return true
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, dynamic> getResponseMetadata() {
    return {'model': model, 'provider': 'rest', ..._lastMetadata};
  }

  @override
  Future<void> dispose() async {
    // No resources to clean up for REST API
    debugPrint('🗑️ REST AI service disposed');
  }
}
