import 'ai_service.dart';
import 'apple_intelligence_service.dart';
import 'rest_ai_service.dart';

/// Factory for creating AI service instances based on model name
class AIServiceFactory {
  /// Create an AI service for the specified model
  /// [sessionId] is used for REST services to maintain conversation context
  static AIService createService(String modelName, {String? sessionId}) {
    switch (modelName) {
      case 'ChatGPT':
      case 'Gemini':
        return RestAIService(modelName, sessionId: sessionId);

      case 'Apple Intelligence':
        return AppleIntelligenceService();

      case 'Hybrid':
        return RestAIService('Hybrid', sessionId: sessionId);

      default:
        throw AIServiceException(
          'Unknown model: $modelName',
          code: 'UNKNOWN_MODEL',
        );
    }
  }

  /// Get list of all available models
  static List<String> getAvailableModels() {
    return [
      'ChatGPT',
      'Gemini',
      'Apple Intelligence',
      'Hybrid',
    ];
  }

  /// Check if a model is available
  static Future<bool> isModelAvailable(String modelName, {String? sessionId}) async {
    try {
      final service = createService(modelName, sessionId: sessionId);
      final available = await service.isAvailable();
      await service.dispose();
      return available;
    } catch (e) {
      return false;
    }
  }
}
