import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

/// Service to manage offline storage for routes and conversations
/// Uses SharedPreferences to store data locally for offline access
class OfflineStorageService {
  static const String _savedRoutesKey = 'offline_saved_routes';
  static const String _conversationsKey = 'offline_conversations';
  static const String _conversationMessagesPrefix = 'offline_messages_';
  static const int _maxConversations = 10; // Limit stored conversations
  static const int _maxMessagesPerConversation = 50; // Limit messages per conversation

  /// Save a route to offline storage
  /// Routes are stored as JSON in SharedPreferences
  static Future<bool> saveRoute({
    required String id,
    required String name,
    required List<Map<String, dynamic>> locations,
    required String? routeType,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing routes
      final routesJson = prefs.getString(_savedRoutesKey);
      final List<dynamic> routes = routesJson != null
          ? jsonDecode(routesJson) as List<dynamic>
          : [];

      // Create route object
      final route = {
        'id': id,
        'name': name,
        'locationCount': locations.length,
        'locations': locations,
        'routeType': routeType,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

      // Remove existing route with same ID if it exists
      routes.removeWhere((r) => r['id'] == id);

      // Add new route at the beginning
      routes.insert(0, route);

      // Save back to SharedPreferences
      final success = await prefs.setString(
        _savedRoutesKey,
        jsonEncode(routes),
      );

      if (success) {
        debugPrint('✅ Route "$name" saved to offline storage');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error saving route to offline storage: $e');
      return false;
    }
  }

  /// Get all offline saved routes
  static Future<List<Map<String, dynamic>>> getSavedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getString(_savedRoutesKey);

      if (routesJson == null) {
        return [];
      }

      final List<dynamic> routes = jsonDecode(routesJson) as List<dynamic>;
      return routes.map((r) => r as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Error loading offline routes: $e');
      return [];
    }
  }

  /// Delete a route from offline storage
  static Future<bool> deleteRoute(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getString(_savedRoutesKey);

      if (routesJson == null) {
        return false;
      }

      final List<dynamic> routes = jsonDecode(routesJson) as List<dynamic>;
      routes.removeWhere((r) => r['id'] == id);

      final success = await prefs.setString(
        _savedRoutesKey,
        jsonEncode(routes),
      );

      if (success) {
        debugPrint('✅ Route deleted from offline storage');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error deleting offline route: $e');
      return false;
    }
  }

  /// Save a conversation to offline storage
  /// Only the most recent conversations are kept (up to _maxConversations)
  static Future<bool> saveConversation({
    required String id,
    required String userId,
    required String title,
    required String currentModel,
    required int messageCount,
    required DateTime updatedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing conversations
      final conversationsJson = prefs.getString(_conversationsKey);
      final List<dynamic> conversations = conversationsJson != null
          ? jsonDecode(conversationsJson) as List<dynamic>
          : [];

      // Create conversation object
      final conversation = {
        'id': id,
        'userId': userId,
        'title': title,
        'currentModel': currentModel,
        'messageCount': messageCount,
        'updatedAt': updatedAt.toIso8601String(),
      };

      // Remove existing conversation with same ID if it exists
      conversations.removeWhere((c) => c['id'] == id);

      // Add new conversation at the beginning
      conversations.insert(0, conversation);

      // Keep only the most recent conversations
      if (conversations.length > _maxConversations) {
        // Remove old conversations and their messages
        for (int i = _maxConversations; i < conversations.length; i++) {
          final oldId = conversations[i]['id'] as String;
          await prefs.remove('$_conversationMessagesPrefix$oldId');
        }
        conversations.removeRange(_maxConversations, conversations.length);
      }

      // Save back to SharedPreferences
      final success = await prefs.setString(
        _conversationsKey,
        jsonEncode(conversations),
      );

      if (success) {
        debugPrint('✅ Conversation "$title" saved to offline storage');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error saving conversation to offline storage: $e');
      return false;
    }
  }

  /// Save messages for a conversation
  /// Only the most recent messages are kept (up to _maxMessagesPerConversation)
  static Future<bool> saveConversationMessages({
    required String conversationId,
    required List<ChatMessage> messages,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limit to most recent messages
      final limitedMessages = messages.length > _maxMessagesPerConversation
          ? messages.sublist(messages.length - _maxMessagesPerConversation)
          : messages;

      // Convert messages to JSON
      final messagesJson = limitedMessages.map((msg) => {
        'content': msg.content,
        'isUser': msg.isUser,
        'timestamp': msg.timestamp.toIso8601String(),
        'model': msg.model,
        'metadata': msg.metadata,
      }).toList();

      final success = await prefs.setString(
        '$_conversationMessagesPrefix$conversationId',
        jsonEncode(messagesJson),
      );

      if (success) {
        debugPrint(
          '✅ ${limitedMessages.length} messages saved for conversation $conversationId',
        );
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error saving conversation messages: $e');
      return false;
    }
  }

  /// Get all offline conversations
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsJson = prefs.getString(_conversationsKey);

      if (conversationsJson == null) {
        return [];
      }

      final List<dynamic> conversations = jsonDecode(conversationsJson) as List<dynamic>;
      return conversations.map((c) => c as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Error loading offline conversations: $e');
      return [];
    }
  }

  /// Get messages for a specific conversation
  static Future<List<ChatMessage>> getConversationMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString('$_conversationMessagesPrefix$conversationId');

      if (messagesJson == null) {
        return [];
      }

      final List<dynamic> messages = jsonDecode(messagesJson) as List<dynamic>;
      return messages.map((m) {
        final map = m as Map<String, dynamic>;
        return ChatMessage(
          content: map['content'] as String,
          isUser: map['isUser'] as bool,
          timestamp: DateTime.parse(map['timestamp'] as String),
          model: map['model'] as String?,
          metadata: map['metadata'] as Map<String, dynamic>?,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading offline conversation messages: $e');
      return [];
    }
  }

  /// Get offline storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Count routes
      final routesJson = prefs.getString(_savedRoutesKey);
      final routesCount = routesJson != null
          ? (jsonDecode(routesJson) as List).length
          : 0;

      // Count conversations
      final conversationsJson = prefs.getString(_conversationsKey);
      final conversationsCount = conversationsJson != null
          ? (jsonDecode(conversationsJson) as List).length
          : 0;

      // Calculate approximate storage size
      int totalSize = 0;
      if (routesJson != null) {
        totalSize += routesJson.length;
      }
      if (conversationsJson != null) {
        totalSize += conversationsJson.length;
      }

      // Add messages size
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_conversationMessagesPrefix)) {
          final value = prefs.getString(key);
          if (value != null) {
            totalSize += value.length;
          }
        }
      }

      return {
        'routesCount': routesCount,
        'conversationsCount': conversationsCount,
        'totalSizeBytes': totalSize,
        'totalSizeKB': (totalSize / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      debugPrint('❌ Error getting storage stats: $e');
      return {
        'routesCount': 0,
        'conversationsCount': 0,
        'totalSizeBytes': 0,
        'totalSizeKB': '0',
      };
    }
  }

  /// Clear all offline data
  static Future<bool> clearAllOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove routes
      await prefs.remove(_savedRoutesKey);

      // Remove conversations
      await prefs.remove(_conversationsKey);

      // Remove all conversation messages
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_conversationMessagesPrefix)) {
          await prefs.remove(key);
        }
      }

      debugPrint('✅ All offline data cleared');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing offline data: $e');
      return false;
    }
  }
}
