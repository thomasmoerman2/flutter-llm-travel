import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/chat_message.dart';
import '../services/firestore_access.dart';
import '../services/theme_color.dart';
import '../services/mapbox_directions_service.dart';
import '../widgets/top_navigation_bar.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/conversation_sidebar.dart';
import 'compare_page.dart';
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
  final GlobalKey<ComparePageContentState> _comparePageKey =
      GlobalKey<ComparePageContentState>();
  final GlobalKey<MapPageContentState> _mapPageKey =
      GlobalKey<MapPageContentState>();
  bool _isSidebarOpen = false;
  final FirestoreAccess _firestore = FirestoreAccess();
  List<LocationData> _displayedLocations = [];
  RouteType? _displayedRouteType;

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
      final didReset = await state.startNewConversation();
      if (didReset) {
        _mapPageKey.currentState?.resetMap();
        setState(() {
          _currentIndex = 0;
        });
      }
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
    if (state != null && state.currentConversationId == conversation.id) {
      final didReset = await state.startNewConversation();
      if (didReset) {
        _mapPageKey.currentState?.resetMap();
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  void _openSavedRoutesSheet() {
    _mapPageKey.currentState?.showSavedRoutesSheet();
  }

  /// Handle when user selects a result from compare page
  Future<void> _handleCompareResultSelected(String prompt, String response, String modelName) async {
    final homeState = _homePageKey.currentState;
    if (homeState != null) {
      // Start a new conversation with the selected result
      final success = await homeState.startConversationWithResult(prompt, response, modelName);
      if (success && mounted) {
        // Reset map when starting new conversation
        _mapPageKey.currentState?.resetMap();
        setState(() {
          _currentIndex = 0;
          _displayedLocations = [];
          _displayedRouteType = null;
        });
      }
    }
  }

  /// Show locations on map with route
  void _showLocationsOnMap(List<LocationData> locations, RouteType? routeType) {
    // debugPrint('🗺️ RootLayout._showLocationsOnMap called with ${locations.length} locations');
    // debugPrint('   Route type: ${routeType?.name ?? "none"}');

    if (_isSidebarOpen) {
      // debugPrint('   Closing sidebar first');
      _closeSidebar();
    }

    // debugPrint('   Switching to map tab (index 2)');
    setState(() {
      _currentIndex = 2;
      _displayedLocations = locations;
      _displayedRouteType = routeType;
    });

    // debugPrint('   Map state is ${_mapPageKey.currentState != null ? "available" : "NULL"}');

    if (routeType != null) {
      // debugPrint('✅ Calling showRouteOnMap on map');
      _mapPageKey.currentState?.showRouteOnMap(locations, routeType);
    } else {
      // debugPrint('✅ Calling showLocationsOnMap on map');
      _mapPageKey.currentState?.showLocationsOnMap(locations);
    }
  }

  void _showLocationsListSheet() {
    _mapPageKey.currentState?.showLocationsListSheet(
      _displayedLocations,
      _displayedRouteType,
      onRouteUpdated: (newLocations, newRouteType) {
        // Update the displayed route when user reorders and shows route
        setState(() {
          _displayedLocations = newLocations;
          _displayedRouteType = newRouteType;
        });
      },
    );
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
    final isMapPage = _currentIndex == 2;
    final navHeight = 60.0 + MediaQuery.of(context).padding.bottom;
    final mapBottomInset = navHeight + 16.0;

    final pageStack = IndexedStack(
      index: _currentIndex,
      // Key forces rebuild when locale changes
      key: ValueKey(context.locale.toString()),
      children: [
        HomePageContent(
          key: _homePageKey,
          onShowOnMap: _showLocationsOnMap,
        ),
        ComparePageContent(
          key: _comparePageKey,
          onSelectResult: _handleCompareResultSelected,
        ),
        MapPageContent(
          key: _mapPageKey,
          bottomInset: mapBottomInset,
          onRouteDisplayed: (locations, routeType) {
            if (!mounted) return;
            setState(() {
              _displayedLocations = locations;
              _displayedRouteType = routeType;
            });
          },
        ),
      ],
    );

    final content = isMapPage
        ? Stack(
            children: [
              Positioned.fill(child: pageStack),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TopNavigationBar(
                  onMenuTap: _openSidebar,
                  onSettingsTap: _navigateToSettings,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomNavigation(
                  currentIndex: _currentIndex,
                  onTap: _handleNavigation,
                  onMapActionTap: _openSavedRoutesSheet,
                  onLocationsListTap: _displayedLocations.isNotEmpty ? _showLocationsListSheet : null,
                  showLocationsButton: _displayedLocations.isNotEmpty,
                ),
              ),
            ],
          )
        : Column(
            children: [
              // Persistent Top Navigation
              TopNavigationBar(
                onMenuTap: _openSidebar,
                onSettingsTap: _navigateToSettings,
              ),

              // Dynamic Content based on selected index
              Expanded(child: pageStack),

              // Persistent Bottom Navigation
              BottomNavigation(
                currentIndex: _currentIndex,
                onTap: _handleNavigation,
                onLocationsListTap: _displayedLocations.isNotEmpty ? _showLocationsListSheet : null,
                showLocationsButton: _displayedLocations.isNotEmpty,
              ),
            ],
          );

    return Stack(
      children: [
        IgnorePointer(
          ignoring: _isSidebarOpen,
          child: Container(color: ThemeColor.background, child: content),
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
                child: Container(color: const Color(0x33000000)),
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
            selectedConversationId:
                _homePageKey.currentState?.currentConversationId,
            onNewConversation: _handleNewConversation,
            onSelectConversation: _handleOpenConversation,
            onDeleteConversation: _handleDeleteConversation,
          ),
        ),
      ],
    );
  }
}
