import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/chat_message.dart';
import '../env_config.dart';
import 'ai_service.dart';
import 'apple_intelligence_service.dart';

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
    final baseUrl = EnvConfig.apiBaseUrl;
    String endpoint;

    switch (model.toLowerCase()) {
      case 'chatgpt':
        endpoint = '/model/gpt';
        break;
      case 'gemini':
        endpoint = '/model/gemini';
        break;
      case 'hybrid':
        endpoint = '/model/hybrid';
        break;
      default:
        endpoint = '/model/gpt'; // Default to ChatGPT (GPT endpoint)
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

      // Build complete message with system prompt and conversation history
      final completeMessage = '$systemPrompt\n\n$message';

      // Prepare request body matching NEW backend API format
      final requestBody = {
        'message': completeMessage,
      };

      debugPrint('📤 Sending REST request to: $apiUrl');
      debugPrint('📝 Request body: ${jsonEncode(requestBody)}');

      // Send POST request with timeout
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
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
      debugPrint('⏱️ Response received after ${elapsed}s (status: ${response.statusCode})');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('📥 Response data keys: ${responseData.keys.join(", ")}');

        // Update metadata
        _lastMetadata = {
          'model': model,
          'provider': 'rest',
          'enhanced': model.toLowerCase() == 'hybrid' && Platform.isIOS,
        };

        // Extract response from NEW backend format
        final responseText = responseData['response'];

        // Handle both string and object responses (Gemini might return object)
        String content;
        if (responseText is String) {
          content = responseText;
        } else if (responseText is Map) {
          // For Gemini responses that might be objects, convert to JSON string
          content = jsonEncode(responseText);
        } else {
          throw AIServiceException(
            'Unexpected response format from server',
            code: 'INVALID_RESPONSE',
          );
        }

        debugPrint('✅ Response complete (${content.length} chars)');

        // For Hybrid model, pass response to Apple Intelligence for refinement
        if (model.toLowerCase() == 'hybrid' && Platform.isIOS) {
          debugPrint('🔄 Hybrid mode: Passing response to Apple Intelligence for refinement...');

          try {
            final appleService = AppleIntelligenceService();

            // Check if Apple Intelligence is available
            final isAvailable = await appleService.isAvailable();
            if (!isAvailable) {
              debugPrint('⚠️ Apple Intelligence not available, returning hybrid response directly');
              yield content;
              return;
            }

            // Initialize Apple Intelligence
            await appleService.initialize();

            // Create refinement prompt
            final refinementMessage = '''Please refine and enhance this travel recommendation response.
Improve the formatting, add any helpful details, and ensure it's well-structured.
IMPORTANT: If the original response contains a JSON code block with location data, you MUST preserve it exactly as-is at the end of your response.

Original response:
$content

Enhanced response:''';

            // Stream the refined response
            await for (final chunk in appleService.sendMessage(
              refinementMessage,
              [],
              'hybrid-refinement',
            )) {
              debugPrint('✅ Apple Intelligence refined response (${chunk.length} chars)');
              yield chunk;
            }

            // Clean up
            await appleService.dispose();
          } catch (e) {
            debugPrint('❌ Failed to refine with Apple Intelligence: $e');
            debugPrint('⚠️ Falling back to hybrid response without refinement');
            yield content;
          }
        } else {
          // For non-hybrid models or non-iOS platforms, yield response directly
          yield content;
        }
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('❌ Bad request (400): ${errorData['error']}');
        throw AIServiceException(
          errorData['error'] ?? 'Bad request',
          code: 'BAD_REQUEST',
        );
      } else if (response.statusCode == 500) {
        debugPrint('❌ Server error (500): API key not configured');
        throw AIServiceException(
          'Server error: ${model.toUpperCase()} API key not configured',
          code: 'SERVER_ERROR',
        );
      } else if (response.statusCode == 503) {
        debugPrint('❌ Service unavailable (503)');
        throw AIServiceException(
          '${model.toUpperCase()} service is currently unavailable',
          code: 'SERVICE_UNAVAILABLE',
        );
      } else if (response.statusCode == 504) {
        debugPrint('❌ Gateway timeout (504)');
        throw AIServiceException(
          'Request to ${model.toUpperCase()} timed out',
          code: 'GATEWAY_TIMEOUT',
        );
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
