import '../../models/chat_message.dart';

/// Abstract interface for AI services
abstract class AIService {
  /// The name of the AI model
  String get modelName;

  /// Initialize the AI service
  Future<void> initialize();

  /// Send a message and get a streaming response
  /// Returns a stream of text chunks for word-by-word display
  Stream<String> sendMessage(
    String message,
    List<ChatMessage> conversationHistory,
    String userId,
  );

  /// Check if the service is available
  Future<bool> isAvailable();

  /// Dispose of any resources
  Future<void> dispose();

  /// Get metadata/header information for the response
  /// This returns information like model version, response time, etc.
  Map<String, dynamic> getResponseMetadata();
}

/// Exception thrown by AI services
class AIServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AIServiceException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AIServiceException: $message${code != null ? ' ($code)' : ''}';
}
