import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message.dart';
import 'ai_service.dart';

/// Apple Intelligence on-device AI service
///
/// Integrates with Apple Intelligence framework via platform channel
/// for on-device AI processing with complete privacy.
class AppleIntelligenceService implements AIService {
  static const platform = MethodChannel('com.travel.app/apple_intelligence');

  bool _initialized = false;
  final Map<String, dynamic> _metadata = {
    'provider': 'apple',
    'onDevice': true,
    'version': '1.0',
  };

  @override
  String get modelName => 'Apple Intelligence';

  @override
  Future<void> initialize() async {
    // Check if running on iOS
    if (!Platform.isIOS) {
      throw AIServiceException(
        'Apple Intelligence is only available on iOS devices',
        code: 'PLATFORM_NOT_SUPPORTED',
      );
    }

    try {
      // debugPrint('🍎 Initializing Apple Intelligence...');
      final result = await platform.invokeMethod('initialize');
      _initialized = result == true;

      if (_initialized) {
        // debugPrint('✅ Apple Intelligence initialized successfully');
      } else {
        throw AIServiceException(
          'Failed to initialize Apple Intelligence',
          code: 'INITIALIZATION_FAILED',
        );
      }
    } on PlatformException catch (e) {
      // debugPrint('❌ Apple Intelligence initialization failed: ${e.message}');
      throw AIServiceException(
        e.message ?? 'Failed to initialize Apple Intelligence',
        code: e.code,
      );
    }
  }

  @override
  Stream<String> sendMessage(
    String message,
    List<ChatMessage> conversationHistory,
    String userId,
  ) async* {
    if (!_initialized) {
      throw AIServiceException('Service not initialized');
    }

    final startTime = DateTime.now();

    try {
      // debugPrint('🍎 Sending message to Apple Intelligence...');
      // debugPrint('📝 Message: $message');

      // Convert conversation history to format expected by Swift
      final history = conversationHistory.map((msg) => {
        'content': msg.content,
        'isUser': msg.isUser,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
      }).toList();

      // Call Swift method via platform channel
      final response = await platform.invokeMethod('sendMessage', {
        'message': message,
        'conversationHistory': history,
      });

      final elapsed = DateTime.now().difference(startTime).inSeconds;
      // debugPrint('⏱️ Apple Intelligence response received after ${elapsed}s');

      if (response is String) {
        // debugPrint('✅ Response: ${response.length} characters');

        // Update metadata
        _metadata['processingTime'] = DateTime.now().millisecondsSinceEpoch;
        _metadata['responseLength'] = response.length;

        // Yield the complete response
        yield response;
      } else {
        throw AIServiceException(
          'Invalid response format from Apple Intelligence',
          code: 'INVALID_RESPONSE',
        );
      }
    } on PlatformException catch (e) {
      // debugPrint('❌ Apple Intelligence error: ${e.message}');
      throw AIServiceException(
        e.message ?? 'Failed to process message on-device',
        code: e.code,
      );
    } catch (e) {
      // debugPrint('❌ Error processing message: $e');
      throw AIServiceException(
        'Failed to process message on-device',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await platform.invokeMethod('isAvailable');
      return result == true;
    } catch (e) {
      // debugPrint('⚠️ Apple Intelligence availability check failed: $e');
      return false;
    }
  }

  @override
  Map<String, dynamic> getResponseMetadata() {
    return {
      ..._metadata,
      'features': [
        'on-device processing',
        'complete privacy',
        'offline capable',
      ],
    };
  }

  @override
  Future<void> dispose() async {
    // TODO: Clean up Apple Intelligence resources when API is available
    _initialized = false;
  }
}
