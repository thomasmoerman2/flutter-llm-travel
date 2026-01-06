import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/firestore_access.dart';
import '../services/preferences_service.dart';
import '../services/theme_color.dart';
import '../widgets/chat_message_bubble.dart';

/// Content-only widget for the home page (without navigation)
/// Used inside RootLayout
class HomePageContent extends StatefulWidget {
  final String? initialModel;

  const HomePageContent({super.key, this.initialModel});

  @override
  State<HomePageContent> createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final FirestoreAccess _firestore = FirestoreAccess();
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  String? _conversationId;
  String _currentModel = 'ChatGPT';
  List<ChatMessage> _messages = [];
  bool _isInitialized = false;
  bool _isSending = false;

  String? get currentConversationId => _conversationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload model preference when app becomes active (returning from settings)
    if (state == AppLifecycleState.resumed) {
      _refreshModelPreference();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also refresh when dependencies change (e.g., when navigating back)
    if (_isInitialized) {
      _refreshModelPreference();
    }
  }

  /// Public method to refresh model preference (called from RootLayout)
  Future<void> refreshModelPreference() async {
    final newModel = await PreferencesService.getSelectedModel();
    if (mounted && newModel != _currentModel) {
      debugPrint('🔄 Model changed from $_currentModel to $newModel');

      // Update ChatService to use new model
      try {
        if (_conversationId != null) {
          await _chatService.switchModel(newModel);
          debugPrint('✅ ChatService switched to $newModel');
        } else {
          // If conversation not initialized yet, just update the model
          // It will use the new model when initialized
          debugPrint('💡 Conversation not initialized yet, will use $newModel on next message');
        }
      } catch (e) {
        debugPrint('⚠️ Error switching model: $e');
      }

      setState(() {
        _currentModel = newModel;
      });
    }
  }

  // Internal alias for backward compatibility
  Future<void> _refreshModelPreference() => refreshModelPreference();

  Future<void> _loadModelPreference() async {
    if (widget.initialModel != null) {
      _currentModel = widget.initialModel!;
    } else {
      _currentModel = await PreferencesService.getSelectedModel();
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Load the saved model preference first
      await _loadModelPreference();

      // Initialize conversation for both logged-in and guest users
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Logged-in user: Load the most recent conversation if it exists
        final conversations = await _firestore.getConversations(user.uid).first;
        Conversation? latestConversation;
        for (final conversation in conversations) {
          if (conversation.messageCount > 0) {
            latestConversation = conversation;
            break;
          }
        }

        if (latestConversation != null) {
          await openConversation(latestConversation);
        } else {
          _conversationId = null;
          _messages = [];
        }
      }
      // Guest users can view the UI but need to login to send messages

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _subscribeToConversation(String conversationId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _firestore.getMessages(conversationId).listen(
      (messages) {
        debugPrint('📨 Received ${messages.length} messages from Firestore');
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        debugPrint('⚠️ Firestore listener error: $error');
        // If index missing, show helpful message
        if (error.toString().contains('requires an index')) {
          debugPrint('💡 Please create the Firestore index using: firebase deploy --only firestore:indexes');
        }
        // Continue without Firestore - WebSocket will still work
      },
    );
  }

  Future<void> startNewConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _promptLoginRequired();
      return;
    }

    await _chatService.resetConversation();
    _messagesSubscription?.cancel();
    if (!mounted) return;

    setState(() {
      _conversationId = null;
      _messages = [];
    });
  }

  Future<void> openConversation(Conversation conversation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _promptLoginRequired();
      return;
    }

    final conversationId = await _chatService.initializeConversation(
      conversation.currentModel,
      conversationId: conversation.id,
    );
    if (!mounted) return;

    setState(() {
      _currentModel = conversation.currentModel;
      _conversationId = conversationId;
      _messages = [];
    });
    _subscribeToConversation(conversationId);
  }

  Future<void> _handleGuestMessage() async {
    _promptLoginRequired();
  }

  void _promptLoginRequired() {
    // Show login prompt for guest users
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'Please log in to send messages and save your conversations.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Log In'),
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login page
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    _textController.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Logged-in user: Use ChatService (saves to Firestore)
        debugPrint('💬 Sending message: $text');
        final hadNoConversation = _conversationId == null;
        final conversationId =
            await _chatService.ensureConversation(_currentModel);
        if (!mounted) return;
        if (_conversationId != conversationId) {
          setState(() {
            _conversationId = conversationId;
            if (hadNoConversation) {
              _messages = [];
            }
          });
          _subscribeToConversation(conversationId);
        }
        await _chatService.sendMessage(text);
        debugPrint('✅ Message sent successfully');
      } else {
        // Guest user: Handle messages locally
        await _handleGuestMessage();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showError('Failed to send message: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }


  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatMessageBubble(
                        message: _messages[index],
                        showModel: index == 0 ||
                            _messages[index].model != _messages[index - 1].model,
                      );
                    },
                  ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColor.background,
              border: Border(
                top: BorderSide(
                  color: ThemeColor.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _textController,
                    placeholder: 'home.input_placeholder'.tr(),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    enabled: !_isSending,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ThemeColor.inputBackground,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSending ? null : _handleSend,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isSending
                          ? ThemeColor.textSecondary.withOpacity(0.3)
                          : ThemeColor.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Center(
                            child: CupertinoActivityIndicator(
                              color: ThemeColor.background,
                            ),
                          )
                        : const Icon(
                            LucideIcons.send,
                            size: 20,
                            color: ThemeColor.background,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getModelIcon(_currentModel),
              size: 64,
              color: ThemeColor.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'home.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ThemeColor.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'home.subtitle'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: ThemeColor.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModelIcon(String model) {
    switch (model) {
      case 'ChatGPT':
        return LucideIcons.messageSquare;
      case 'Gemini':
        return LucideIcons.sparkles;
      case 'Apple Intelligence':
      case 'apple_intelligence':
        return LucideIcons.cpu;
      case 'Hybrid':
        return LucideIcons.zap;
      default:
        return LucideIcons.bot;
    }
  }
}
