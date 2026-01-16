import 'dart:async';
import 'package:app/routes/login_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/env_config.dart';
import '../services/firestore_access.dart';
import '../services/preferences_service.dart';
import '../services/theme_color.dart';
import '../services/mapbox_directions_service.dart';
import '../widgets/chat_message_bubble.dart';

/// Content-only widget for the home page (without navigation)
/// Used inside RootLayout
class HomePageContent extends StatefulWidget {
  final String? initialModel;
  final void Function(List<LocationData> locations, RouteType? routeType)?
  onShowOnMap;

  const HomePageContent({super.key, this.initialModel, this.onShowOnMap});

  @override
  State<HomePageContent> createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent>
    with WidgetsBindingObserver {
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
  bool _isApiAvailable = true;
  bool _isCheckingApi = false;
  DateTime? _lastScrollTime;

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

  /// Check if REST API is available for REST-based models
  bool _isRestModel(String model) {
    return model == 'ChatGPT' || model == 'Gemini' || model == 'Hybrid';
  }

  /// Check API availability by pinging the backend
  Future<void> _checkApiAvailability() async {
    if (!_isRestModel(_currentModel)) {
      // Apple Intelligence doesn't need API check
      setState(() {
        _isApiAvailable = true;
      });
      return;
    }

    setState(() {
      _isCheckingApi = true;
    });

    try {
      debugPrint('🔍 Checking API availability at ${EnvConfig.apiBaseUrl}');

      // Try to connect to the base URL or a known endpoint
      // We'll use a simple GET to the base URL with a short timeout
      final response = await http
          .get(Uri.parse(EnvConfig.apiBaseUrl))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException('API connection timeout');
            },
          );

      // Accept any response code (200, 404, etc.) as long as we got a response
      // This means the server is reachable
      final isAvailable = response.statusCode >= 0;
      debugPrint(
        isAvailable
            ? '✅ API is available (status: ${response.statusCode})'
            : '❌ API unavailable',
      );

      if (mounted) {
        setState(() {
          _isApiAvailable = isAvailable;
          _isCheckingApi = false;
        });
      }
    } catch (e) {
      debugPrint('❌ API check failed: $e');
      if (mounted) {
        setState(() {
          _isApiAvailable = false;
          _isCheckingApi = false;
        });
      }
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
          debugPrint(
            '💡 Conversation not initialized yet, will use $newModel on next message',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error switching model: $e');
      }

      setState(() {
        _currentModel = newModel;
      });

      // Check API availability when switching to REST models
      await _checkApiAvailability();
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

      // Check API availability for REST models
      await _checkApiAvailability();

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
    // Throttle scroll animations to prevent flickering during streaming
    final now = DateTime.now();
    if (_lastScrollTime != null &&
        now.difference(_lastScrollTime!) < const Duration(milliseconds: 500)) {
      return; // Skip if we scrolled recently
    }
    _lastScrollTime = now;

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
    _messagesSubscription = _firestore
        .getMessages(conversationId)
        .listen(
          (messages) {
            debugPrint(
              '📨 Received ${messages.length} messages from Firestore',
            );
            if (mounted) {
              // Check if we should update (avoid rebuilds during rapid streaming)
              final shouldUpdate =
                  _messages.isEmpty ||
                  messages.length != _messages.length ||
                  (messages.isNotEmpty &&
                      _messages.isNotEmpty &&
                      messages.last.content != _messages.last.content);

              if (shouldUpdate) {
                setState(() {
                  _messages = messages;
                });
                _scrollToBottom();
              }
            }
          },
          onError: (error) {
            debugPrint('⚠️ Firestore listener error: $error');
            // If index missing, show helpful message
            if (error.toString().contains('requires an index')) {
              debugPrint(
                '💡 Please create the Firestore index using: firebase deploy --only firestore:indexes',
              );
            }
            // Continue without Firestore - WebSocket will still work
          },
        );
  }

  Future<bool> startNewConversation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _promptLoginRequired();
      return false;
    }

    await _chatService.resetConversation();
    _messagesSubscription?.cancel();
    if (!mounted) return false;

    setState(() {
      _conversationId = null;
      _messages = [];
    });
    return true;
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
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => const LoginPage()),
              );
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
        final conversationId = await _chatService.ensureConversation(
          _currentModel,
        );
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

  Future<void> _resendMessage(String text) async {
    if (_isSending) return;
    _textController.text = text;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    await _handleSend();
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

  void _handleShowOnMap(ChatMessage message) {
    debugPrint('🗺️ _handleShowOnMap called');
    final callback = widget.onShowOnMap;
    if (callback == null) {
      debugPrint('❌ No onShowOnMap callback provided');
      return;
    }

    final locations = _extractLocations(message);
    debugPrint('📍 Extracted ${locations.length} locations from message');
    if (locations.isEmpty) {
      debugPrint('❌ No locations found in message metadata');
      _showError('No locations found for this response.');
      return;
    }

    for (var i = 0; i < locations.length; i++) {
      debugPrint(
        '   Location $i: ${locations[i].name} (${locations[i].latitude}, ${locations[i].longitude})',
      );
    }

    final routeType = _extractRouteType(message);
    debugPrint('🛣️ Route type: ${routeType?.name ?? "none"}');
    debugPrint('✅ Calling onShowOnMap callback');
    callback(locations, routeType);
  }

  void _handleSelectRouteOption(RouteOption option) {
    debugPrint('📍 Route option selected: ${option.name}');
    debugPrint('   ${option.locations.length} locations in this option');

    final callback = widget.onShowOnMap;
    if (callback == null) {
      debugPrint('❌ No onShowOnMap callback provided');
      return;
    }

    // Auto-detect route type based on locations
    final routeType = MapboxDirectionsService.detectRouteType(option.locations);
    debugPrint('🛣️ Detected route type: ${routeType.name}');
    debugPrint('✅ Calling onShowOnMap callback with route option');
    callback(option.locations, routeType);
  }

  List<LocationData> _extractLocations(ChatMessage message) {
    final locationsData = message.metadata?['locations'];
    if (locationsData is! List) return [];

    final locations = <LocationData>[];
    for (final entry in locationsData) {
      if (entry is Map<String, dynamic>) {
        try {
          locations.add(LocationData.fromJson(entry));
        } catch (_) {}
      }
    }
    return locations;
  }

  RouteType? _extractRouteType(ChatMessage message) {
    final routeTypeValue = message.metadata?['routeType'];
    if (routeTypeValue is String) {
      final normalized = routeTypeValue.toLowerCase();
      if (normalized.contains('walk')) return RouteType.walking;
      if (normalized.contains('cycl') || normalized.contains('bike')) {
        return RouteType.cycling;
      }
      if (normalized.contains('drive')) return RouteType.driving;
    }
    return null;
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
      return const Center(child: CupertinoActivityIndicator());
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
                      final message = _messages[index];
                      return ChatMessageBubble(
                        message: message,
                        showModel:
                            index == 0 ||
                            message.model != _messages[index - 1].model,
                        onShowOnMap:
                            (!message.isUser &&
                                (message.hasLocations || message.hasRoute))
                            ? () => _handleShowOnMap(message)
                            : null,
                        onResend: message.isUser
                            ? (text) => _resendMessage(text)
                            : null,
                        onSelectRouteOption: (option) => _handleSelectRouteOption(option),
                      );
                    },
                  ),
          ),

          // Input field
          SafeArea(
            top: false,
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: ThemeColor.background,
                border: Border(
                  top: BorderSide(
                    color: ThemeColor.textSecondary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isCheckingApi)
                        const CupertinoActivityIndicator(radius: 7)
                      else
                        Icon(
                          _getModelIcon(_currentModel),
                          size: 14,
                          color: ThemeColor.textSecondary,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _currentModel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                      if (!_isApiAvailable &&
                          !_isCheckingApi &&
                          _isRestModel(_currentModel)) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          LucideIcons.wifiOff,
                          size: 14,
                          color: Color(0xFFEF5350),
                        ),
                      ],
                    ],
                  ),
                  if (!_isApiAvailable &&
                      !_isCheckingApi &&
                      _isRestModel(_currentModel)) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _checkApiAvailability,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.refreshCw,
                            size: 11,
                            color: Color(0xFFEF5350),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'API unavailable - Tap to retry',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEF5350),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _textController,
                          placeholder:
                              (!_isApiAvailable && _isRestModel(_currentModel))
                              ? 'API unavailable'
                              : 'home.input_placeholder'.tr(),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          enabled: !_isSending && _isApiAvailable,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (!_isApiAvailable &&
                                    _isRestModel(_currentModel))
                                ? ThemeColor.inputBackground.withOpacity(0.5)
                                : ThemeColor.inputBackground,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: (_isSending || !_isApiAvailable)
                            ? null
                            : _handleSend,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (_isSending || !_isApiAvailable)
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
                              : Icon(
                                  !_isApiAvailable &&
                                          _isRestModel(_currentModel)
                                      ? LucideIcons.wifiOff
                                      : LucideIcons.send,
                                  size: 20,
                                  color: ThemeColor.textPrimary,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
