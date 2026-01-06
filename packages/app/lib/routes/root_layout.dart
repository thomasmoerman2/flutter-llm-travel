import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/chat_message.dart';
import '../services/firestore_access.dart';
import '../services/theme_color.dart';
import '../widgets/top_navigation_bar.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/conversation_sidebar.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

class RootLayout extends StatefulWidget {
  final bool isLoggedIn;

  const RootLayout({super.key, this.isLoggedIn = false});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  int _currentIndex = 0;
  final GlobalKey<HomePageContentState> _homePageKey =
      GlobalKey<HomePageContentState>();
  bool _isSidebarOpen = false;
  final FirestoreAccess _firestore = FirestoreAccess();

  void _handleNavigation(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openSidebar() {
    setState(() {
      _isSidebarOpen = true;
    });
  }

  void _closeSidebar() {
    setState(() {
      _isSidebarOpen = false;
    });
  }

  Future<void> _handleNewConversation() async {
    final state = _homePageKey.currentState;
    if (state != null) {
      await state.startNewConversation();
      setState(() {
        _currentIndex = 0;
      });
    }
    _closeSidebar();
  }

  Future<void> _handleOpenConversation(Conversation conversation) async {
    final state = _homePageKey.currentState;
    if (state != null) {
      await state.openConversation(conversation);
      setState(() {
        _currentIndex = 0;
      });
    }
    _closeSidebar();
  }

  Future<void> _handleDeleteConversation(Conversation conversation) async {
    await _firestore.deleteConversation(conversation.id);
    final state = _homePageKey.currentState;
    if (state != null &&
        state.currentConversationId == conversation.id) {
      await state.startNewConversation();
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  void _navigateToSettings() async {
    if (_isSidebarOpen) {
      _closeSidebar();
    }
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => SettingsPage(isLoggedIn: widget.isLoggedIn),
      ),
    );
    // Refresh home page model preference after returning from settings
    final state = _homePageKey.currentState;
    if (state != null) {
      state.refreshModelPreference();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = math.min(screenWidth * 0.78, 320.0);

    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isSidebarOpen,
          child: Container(
            color: ThemeColor.background,
            child: Column(
              children: [
                // Persistent Top Navigation
                TopNavigationBar(
                  onMenuTap: _openSidebar,
                  onSettingsTap: _navigateToSettings,
                ),

                // Dynamic Content based on selected index
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    // Key forces rebuild when locale changes
                    key: ValueKey(context.locale.toString()),
                    children: [
                      HomePageContent(key: _homePageKey),
                      const MapPageContent(),
                    ],
                  ),
                ),

                // Persistent Bottom Navigation
                BottomNavigation(
                  currentIndex: _currentIndex,
                  onTap: _handleNavigation,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isSidebarOpen,
            child: GestureDetector(
              onTap: _closeSidebar,
              child: AnimatedOpacity(
                opacity: _isSidebarOpen ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Container(
                  color: const Color(0x33000000),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: _isSidebarOpen ? 0 : -sidebarWidth,
          top: 0,
          bottom: 0,
          child: ConversationSidebar(
            width: sidebarWidth,
            selectedConversationId: _homePageKey.currentState?.currentConversationId,
            onNewConversation: _handleNewConversation,
            onSelectConversation: _handleOpenConversation,
            onDeleteConversation: _handleDeleteConversation,
          ),
        ),
      ],
    );
  }
}
