import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class FirestoreAccess {
  final db = FirebaseFirestore.instance;

  void init() {
    db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  void createDocument(
    String title,
    String content,
    Timestamp date,
    String pages,
  ) {
    db.collection('chat').add({
      'message': title,
      'content': content,
      'date': date,
      'pages': pages,
    });
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getDocument(String title) {
    return db.collection('write').where('title', isEqualTo: title).get();
  }

  Future<void> updateDocument(
    String title,
    String content,
    Timestamp date,
    String pages,
  ) async {
    var querySnapshot = await getDocument(title);
    if (querySnapshot.docs.isNotEmpty) {
      var docId = querySnapshot.docs.first.id;
      await db.collection('write').doc(docId).update({
        'title': title,
        'content': content,
        'date': date,
        'pages': pages,
      });
    }
  }

  Future<List<Map<String, String>>> getDocuments() async {
    List<Map<String, String>> items = [];
    await db.collection("write").get().then((event) {
      for (var doc in event.docs) {
        items.add({
          "documentId": doc.id,
          "title": doc['title'],
          "date": (doc['date'] as Timestamp)
              .toDate()
              .toString()
              .split(' ')[0]
              .split('-')
              .reversed
              .join('/'),
          "pages": doc['pages'],
          "content": doc['content'],
        });
      }
    });
    return items;
  }

  // ========== Chat Conversations ==========

  /// Create a new conversation
  Future<String> createConversation(Conversation conversation) async {
    final docRef =
        await db.collection('conversations').add(conversation.toFirestore());
    return docRef.id;
  }

  /// Get all conversations for a user
  Stream<List<Conversation>> getConversations(String userId) {
    return db
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Conversation.fromFirestore(doc)).toList());
  }

  /// Update conversation
  Future<void> updateConversation(Conversation conversation) async {
    await db
        .collection('conversations')
        .doc(conversation.id)
        .update(conversation.toFirestore());
  }

  /// Delete conversation and all its messages
  Future<void> deleteConversation(String conversationId) async {
    // Delete all messages in conversation
    final messages = await db
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .get();

    for (var doc in messages.docs) {
      await doc.reference.delete();
    }

    // Delete conversation
    await db.collection('conversations').doc(conversationId).delete();
  }

  // ========== Chat Messages ==========

  /// Add a message to a conversation
  Future<String> addMessage(ChatMessage message) async {
    final docRef = await db.collection('messages').add(message.toFirestore());
    return docRef.id;
  }

  /// Get all messages for a conversation
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return db
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  /// Update a message (useful for streaming updates)
  Future<void> updateMessage(ChatMessage message) async {
    await db.collection('messages').doc(message.id).update(message.toFirestore());
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    await db.collection('messages').doc(messageId).delete();
  }

  /// Get the last message in a conversation
  Future<ChatMessage?> getLastMessage(String conversationId) async {
    final snapshot = await db
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ChatMessage.fromFirestore(snapshot.docs.first);
  }

  // ========== User Preferences ==========

  /// Save user's AI model preference to Firestore
  Future<void> saveUserAIModel(String userId, String aiModel) async {
    await db.collection('users').doc(userId).set({
      'selectedAIModel': aiModel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user's AI model preference from Firestore
  Future<String?> getUserAIModel(String userId) async {
    final doc = await db.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data()?['selectedAIModel'] as String?;
    }
    return null;
  }

  /// Save multiple user preferences at once
  Future<void> saveUserPreferences(String userId, Map<String, dynamic> preferences) async {
    await db.collection('users').doc(userId).set({
      ...preferences,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get all user preferences
  Future<Map<String, dynamic>?> getUserPreferences(String userId) async {
    final doc = await db.collection('users').doc(userId).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }
}
