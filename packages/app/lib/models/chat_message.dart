import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageRole {
  user,
  assistant,
  system,
}

enum MessageStatus {
  sending,
  sent,
  error,
  streaming,
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String userId;
  final String content;
  final MessageRole role;
  final MessageStatus status;
  final String model; // 'ChatGPT', 'Gemini', 'Apple Intelligence', 'Hybrid'
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.content,
    required this.role,
    required this.status,
    required this.model,
    required this.timestamp,
    this.metadata,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'userId': userId,
      'content': content,
      'role': role.name,
      'status': status.name,
      'model': model,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  // Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      role: MessageRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => MessageRole.user,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => MessageStatus.sent,
      ),
      model: data['model'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  // Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? userId,
    String? content,
    MessageRole? role,
    MessageStatus? status,
    String? model,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      role: role ?? this.role,
      status: status ?? this.status,
      model: model ?? this.model,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isSystem => role == MessageRole.system;
  bool get isSending => status == MessageStatus.sending;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get hasError => status == MessageStatus.error;
}

class Conversation {
  final String id;
  final String userId;
  final String title;
  final String currentModel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  Conversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.currentModel,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'currentModel': currentModel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'messageCount': messageCount,
    };
  }

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'New Conversation',
      currentModel: data['currentModel'] ?? 'ChatGPT',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      messageCount: data['messageCount'] ?? 0,
    );
  }

  Conversation copyWith({
    String? id,
    String? userId,
    String? title,
    String? currentModel,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      currentModel: currentModel ?? this.currentModel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}
