import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'ai/ai_service.dart';
import 'ai/ai_service_factory.dart';
import 'firestore_access.dart';
import 'location_parser.dart';
import 'offline_storage_service.dart';

/// Service to manage chat conversations and AI interactions
class ChatService {
  final FirestoreAccess _firestore = FirestoreAccess();
  AIService? _currentAIService;
  String? _currentModel;
  String? _currentConversationId;
  final StreamController<ChatMessage> _messageStreamController =
      StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get messageStream => _messageStreamController.stream;

  /// Initialize or switch to a conversation
  Future<String> initializeConversation(
    String model, {
    String? conversationId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to chat');
    }

    final previousConversationId = _currentConversationId;

    // Create or use existing conversation FIRST (before switching model)
    if (conversationId != null) {
      _currentConversationId = conversationId;
    } else {
      final conversation = Conversation(
        id: '',
        userId: user.uid,
        title: 'New Conversation',
        currentModel: model,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageCount: 0,
      );
      _currentConversationId = await _firestore.createConversation(
        conversation,
      );
    }

    // NOW switch AI service if model changed (with conversationId available)
    final conversationChanged =
        previousConversationId != _currentConversationId;
    if (_currentAIService == null ||
        _currentModel != model ||
        conversationChanged) {
      await _switchModel(model);
    }

    return _currentConversationId!;
  }

  /// Reset active conversation without creating a new one
  Future<void> resetConversation() async {
    await _currentAIService?.dispose();
    _currentAIService = null;
    _currentConversationId = null;
  }

  /// Ensure a conversation exists before sending a message
  Future<String> ensureConversation(String model) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to chat');
    }

    var createdConversation = false;
    if (_currentConversationId == null) {
      final conversation = Conversation(
        id: '',
        userId: user.uid,
        title: 'New Conversation',
        currentModel: model,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageCount: 0,
      );
      _currentConversationId = await _firestore.createConversation(
        conversation,
      );
      createdConversation = true;
    }

    if (_currentAIService == null ||
        _currentModel != model ||
        createdConversation) {
      await _switchModel(model);
    }

    return _currentConversationId!;
  }

  /// Switch AI model with proper cleanup
  Future<void> _switchModel(String newModel) async {
    await _currentAIService?.dispose();
    // Pass conversation ID as sessionId for WebSocket services
    _currentAIService = AIServiceFactory.createService(
      newModel,
      sessionId: _currentConversationId,
    );
    await _currentAIService!.initialize();
    _currentModel = newModel;
  }

  /// Send a message and get streaming response
  Future<void> sendMessage(String messageText) async {
    if (_currentConversationId == null || _currentAIService == null) {
      throw Exception('Conversation not initialized');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in');
    }

    String? aiMessageId;
    ChatMessage? aiMessage;
    String fullResponse = '';
    bool responseCompleted = false;

    try {
      // Create user message
      final userMessage = ChatMessage(
        id: '',
        conversationId: _currentConversationId!,
        userId: user.uid,
        content: messageText,
        role: MessageRole.user,
        status: MessageStatus.sending,
        model: _currentModel!,
        timestamp: DateTime.now(),
      );

      // Save user message to Firestore
      final userMessageId = await _firestore.addMessage(userMessage);
      final savedUserMessage = userMessage.copyWith(
        id: userMessageId,
        status: MessageStatus.sent,
      );
      await _firestore.updateMessage(savedUserMessage);

      // Notify listeners
      _messageStreamController.add(savedUserMessage);

      // Get conversation history
      final history = await _firestore
          .getMessages(_currentConversationId!)
          .first
          .timeout(const Duration(seconds: 5));

      // Create placeholder for AI response
      aiMessage = ChatMessage(
        id: '',
        conversationId: _currentConversationId!,
        userId: user.uid,
        content: '',
        role: MessageRole.assistant,
        status: MessageStatus.streaming,
        model: _currentModel!,
        timestamp: DateTime.now(),
        metadata: _currentAIService!.getResponseMetadata(),
      );

      // Save placeholder to Firestore
      aiMessageId = await _firestore.addMessage(aiMessage);

      // Stream AI response
      await for (final chunk in _currentAIService!.sendMessage(
        messageText,
        history,
        user.uid,
      )) {
        fullResponse += chunk;

        // Update message in Firestore and notify
        final updatedMessage = aiMessage.copyWith(
          id: aiMessageId,
          content: fullResponse,
          status: MessageStatus.streaming,
        );
        await _firestore.updateMessage(updatedMessage);
        _messageStreamController.add(updatedMessage);
      }

      final parsed = LocationParser.parseLocationsAndRoute(fullResponse);
      debugPrint('🗺️ Parsed locations: ${parsed.locations.length} found');
      if (parsed.locations.isNotEmpty) {
        debugPrint('📍 Location details: ${parsed.locations.map((l) => l.name).join(", ")}');
      }
      if (parsed.routeType != null) {
        debugPrint('🛣️ Route type: ${parsed.routeType!.name}');
      }

      final cleanedText = parsed.cleanedText.trim();
      final finalContent = cleanedText.isNotEmpty
          ? cleanedText
          : fullResponse.trim();

      final responseMetadata = Map<String, dynamic>.from(
        _currentAIService!.getResponseMetadata(),
      );
      if (parsed.locations.isNotEmpty) {
        responseMetadata['locations'] =
            parsed.locations.map((location) => location.toJson()).toList();
        debugPrint('✅ Added locations to metadata');
      }
      if (parsed.routeType != null) {
        responseMetadata['routeType'] = parsed.routeType!.name;
        debugPrint('✅ Added routeType to metadata');
      }

      final finalMessage = aiMessage.copyWith(
        id: aiMessageId,
        content: finalContent,
        status: MessageStatus.sent,
        metadata: responseMetadata.isEmpty ? null : responseMetadata,
      );
      await _firestore.updateMessage(finalMessage);
      _messageStreamController.add(finalMessage);
      responseCompleted = true;

      // Update conversation
      await _updateConversation();
    } catch (e) {
      // Handle error - create error message with user-friendly text
      String errorContent;
      if (e is AIServiceException && e.code == 'TIMEOUT') {
        // Custom timeout message
        errorContent =
            '⏱️ The AI took too long to respond (timeout after 60 seconds). Please try again with a simpler question, or check your internet connection.';
      } else if (e is AIServiceException && e.code == 'CONNECTION_ERROR') {
        errorContent =
            '🔌 Connection error. Please check if the backend server is running and try again.';
      } else if (e is AIServiceException && e.code == 'SERVER_ERROR') {
        errorContent = '⚠️ Server error: ${e.message}';
      } else {
        errorContent = '❌ Error: ${e.toString()}';
      }

      if (!responseCompleted && aiMessageId != null && aiMessage != null) {
        final failureContent = fullResponse.trim().isNotEmpty
            ? '${fullResponse.trim()}\n\n$errorContent'
            : errorContent;
        final errorMessage = aiMessage.copyWith(
          id: aiMessageId,
          content: failureContent,
          status: MessageStatus.error,
        );
        await _firestore.updateMessage(errorMessage);
        _messageStreamController.add(errorMessage);
      } else if (!responseCompleted) {
        final errorMessage = ChatMessage(
          id: '',
          conversationId: _currentConversationId!,
          userId: user.uid,
          content: errorContent,
          role: MessageRole.assistant,
          status: MessageStatus.error,
          model: _currentModel!,
          timestamp: DateTime.now(),
        );
        final errorId = await _firestore.addMessage(errorMessage);
        _messageStreamController.add(errorMessage.copyWith(id: errorId));
      }
      rethrow;
    }
  }

  /// Update conversation metadata
  Future<void> _updateConversation() async {
    if (_currentConversationId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messages = await _firestore
        .getMessages(_currentConversationId!)
        .first;
    final title = messages.isNotEmpty
        ? _generateTitle(messages.first.content)
        : 'New Conversation';
    final now = DateTime.now();

    final conversation = Conversation(
      id: _currentConversationId!,
      userId: user.uid,
      title: title,
      currentModel: _currentModel!,
      createdAt: now, // Would need to fetch actual creation time
      updatedAt: now,
      messageCount: messages.length,
    );

    // Update Firestore
    await _firestore.updateConversation(conversation);

    // Also save to offline storage
    await OfflineStorageService.saveConversation(
      id: _currentConversationId!,
      userId: user.uid,
      title: title,
      currentModel: _currentModel!,
      messageCount: messages.length,
      updatedAt: now,
    );

    // Save messages to offline storage
    await OfflineStorageService.saveConversationMessages(
      conversationId: _currentConversationId!,
      messages: messages,
    );
  }

  /// Generate conversation title from first message
  String _generateTitle(String firstMessage) {
    final words = firstMessage.split(' ').take(5).join(' ');
    return words.length > 40 ? '${words.substring(0, 40)}...' : words;
  }

  /// Switch model mid-conversation
  Future<void> switchModel(String newModel) async {
    await _switchModel(newModel);
    if (_currentConversationId != null) {
      await _updateConversation();
    }
  }

  /// Get current model
  String? get currentModel => _currentModel;

  /// Dispose resources
  Future<void> dispose() async {
    await _currentAIService?.dispose();
    await _messageStreamController.close();
  }
}
