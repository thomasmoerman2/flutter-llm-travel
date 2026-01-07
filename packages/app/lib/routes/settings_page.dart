import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/chat_message.dart';
import '../services/theme_color.dart';
import '../services/auth_service.dart';
import '../services/connection_health_service.dart';
import '../services/firestore_access.dart';
import '../services/offline_storage_service.dart';
import '../services/preferences_service.dart';
import 'connection_status_page.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  final bool isLoggedIn;

  const SettingsPage({super.key, this.isLoggedIn = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedModel = 'Apple Intelligence';
  late TextEditingController _displayNameController;
  final AuthService _authService = AuthService();
  final ConnectionHealthService _healthService = ConnectionHealthService();

  User? _currentUser;
  String? _userEmail;
  String? _userDisplayName;
  DateTime? _userCreationTime;
  bool _isIOS = false;
  bool _hasAppleFoundationAccess = false;
  bool _isSavingDisplayName = false;

  ConnectionHealth? _apiHealth;
  ConnectionHealth? _wsHealth;
  bool _isCheckingConnections = false;

  Map<String, dynamic> _offlineStats = {
    'routesCount': 0,
    'conversationsCount': 0,
    'totalSizeKB': '0',
  };
  bool _isLoadingOfflineStats = false;
  bool _isDownloadingData = false;

  @override
  void initState() {
    super.initState();
    _isIOS = Platform.isIOS;
    _hasAppleFoundationAccess = _checkAppleFoundationAccess();
    _loadUserData();
    _checkConnections();
    _loadSelectedModel();
    _loadOfflineStats();
  }

  Future<void> _loadOfflineStats() async {
    debugPrint('📊 [SETTINGS] Loading offline stats...');
    setState(() {
      _isLoadingOfflineStats = true;
    });

    final stats = await OfflineStorageService.getStorageStats();
    debugPrint('📊 [SETTINGS] Received stats: $stats');

    if (mounted) {
      setState(() {
        _offlineStats = stats;
        _isLoadingOfflineStats = false;
      });
      debugPrint('📊 [SETTINGS] Stats updated in UI');
    }
  }

  Future<void> _clearOfflineData() async {
    final shouldClear = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear Offline Data'),
        content: const Text(
          'This will remove all saved routes and conversations from offline storage. You can re-download them when online.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await OfflineStorageService.clearAllOfflineData();
      await _loadOfflineStats();
      if (!mounted) return;
      _showSuccess('Offline data cleared successfully');
    }
  }

  Future<void> _downloadAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You must be logged in to download data');
      return;
    }

    setState(() {
      _isDownloadingData = true;
    });

    int routesDownloaded = 0;
    int conversationsDownloaded = 0;

    try {
      debugPrint('📥 Starting offline data download...');

      // Download all saved routes
      debugPrint('📥 Fetching routes from Firestore...');
      final routesSnapshot = await FirebaseFirestore.instance
          .collection('savedRoutes')
          .where('userId', isEqualTo: user.uid)
          .get();

      debugPrint('📥 Found ${routesSnapshot.docs.length} routes');

      for (final doc in routesSnapshot.docs) {
        final data = doc.data();
        final locations = (data['locations'] as List?)
            ?.map((loc) => loc as Map<String, dynamic>)
            .toList() ?? [];

        await OfflineStorageService.saveRoute(
          id: doc.id,
          name: data['name'] as String? ?? 'Unnamed Route',
          locations: locations,
          routeType: data['routeType'] as String?,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
        routesDownloaded++;
      }

      debugPrint('✅ Downloaded $routesDownloaded routes');

      // Download all conversations
      debugPrint('📥 Fetching conversations from Firestore...');
      final firestoreAccess = FirestoreAccess();
      final conversations = await firestoreAccess.getConversations(user.uid).first;

      debugPrint('📥 Found ${conversations.length} conversations');

      // Limit to 10 most recent conversations
      final conversationsToDownload = conversations.take(10).toList();

      for (final conversation in conversationsToDownload) {
        // Save conversation
        await OfflineStorageService.saveConversation(
          id: conversation.id,
          userId: user.uid,
          title: conversation.title,
          currentModel: conversation.currentModel,
          messageCount: conversation.messageCount,
          updatedAt: conversation.updatedAt,
        );

        // Download messages for this conversation
        final messages = await firestoreAccess.getMessages(conversation.id).first;

        await OfflineStorageService.saveConversationMessages(
          conversationId: conversation.id,
          messages: messages,
        );

        conversationsDownloaded++;
      }

      debugPrint('✅ Downloaded $conversationsDownloaded conversations');

      // Reload stats
      await _loadOfflineStats();

      if (!mounted) return;

      setState(() {
        _isDownloadingData = false;
      });

      _showSuccess(
        'Downloaded $routesDownloaded routes and $conversationsDownloaded conversations',
      );
    } catch (e) {
      debugPrint('❌ Error downloading data: $e');

      if (!mounted) return;

      setState(() {
        _isDownloadingData = false;
      });

      _showError('Failed to download data: ${e.toString()}');
    }
  }

  Future<void> _loadSelectedModel() async {
    final savedModel = await PreferencesService.getSelectedModel();
    if (mounted) {
      setState(() {
        _selectedModel = savedModel;
      });
    }
  }

  Future<void> _checkConnections() async {
    setState(() {
      _isCheckingConnections = true;
    });

    await _healthService.checkAllConnections();

    setState(() {
      _apiHealth = _healthService.apiHealth;
      _wsHealth = _healthService.wsHealth;
      _isCheckingConnections = false;
    });
  }

  Future<void> _saveDisplayName() async {
    final newDisplayName = _displayNameController.text.trim();
    if (newDisplayName.isEmpty) {
      _showError('Display name cannot be empty');
      return;
    }

    if (newDisplayName == _userDisplayName) {
      return; // No change
    }

    setState(() {
      _isSavingDisplayName = true;
    });

    final success = await _authService.updateDisplayName(newDisplayName);

    if (!mounted) return;

    setState(() {
      _isSavingDisplayName = false;
    });

    if (success) {
      setState(() {
        _userDisplayName = newDisplayName;
      });
      _showSuccess('Display name updated successfully');
    } else {
      _showError('Failed to update display name');
    }
  }

  void _showSuccess(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
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

  bool _checkAppleFoundationAccess() {
    // Check if running on iOS 18.0+ for Apple Intelligence
    if (!Platform.isIOS) return false;

    // For now, we assume access is available on iOS
    // You can add more sophisticated checks here based on your requirements
    // For example, checking for specific entitlements or capabilities
    return true;
  }

  void _loadUserData() {
    _currentUser = _authService.getCurrentUser();
    if (_currentUser != null) {
      setState(() {
        _userEmail = _currentUser!.email;
        _userDisplayName = _currentUser!.displayName ?? 'User';
        _userCreationTime = _currentUser!.metadata.creationTime;
        _displayNameController = TextEditingController(text: _userDisplayName);
      });
    } else {
      _displayNameController = TextEditingController(text: 'User');
    }
  }

  int get _daysAgoCreated {
    if (_userCreationTime == null) return 0;
    return DateTime.now().difference(_userCreationTime!).inDays;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  final Map<String, Locale> _languageLocales = {
    'Nederlands': const Locale('nl'),
    'English': const Locale('en'),
    'Français': const Locale('fr'),
  };

  List<String> get _models {
    final models = ['ChatGPT', 'Gemini'];
    if (_isIOS && _hasAppleFoundationAccess) {
      models.add('Apple Intelligence');
      models.add('Hybrid');
    }
    return models;
  }

  bool _isModelDisabled(String model) {
    if (model == 'Apple Intelligence' && !_isIOS) {
      return true;
    }
    return false;
  }

  String? _getModelDisabledReason(String model) {
    if (model == 'Apple Intelligence' && !_isIOS) {
      return 'Only available on iOS devices with iOS 18.0+';
    }
    return null;
  }

  String get _currentLanguageDisplay {
    final locale = context.locale;
    return _languageLocales.entries
        .firstWhere(
          (e) => e.value == locale,
          orElse: () => _languageLocales.entries.first,
        )
        .key;
  }

  void _handleAuthAction() async {
    if (widget.isLoggedIn) {
      // Handle disconnect - show confirmation dialog first
      final shouldLogout = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Disconnect'),
          content: const Text('Are you sure you want to disconnect?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Disconnect'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await _authService.signOut();
        if (!mounted) return;

        // Navigate back to login page and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } else {
      // Navigate to login page
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThemeColor.background,
      child: Column(
        children: [
          // Top Navigation with Connection Status and Back Button
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Connection Status Warning Indicator (only show when there are issues)
                  if (_apiHealth?.hasError == true ||
                      _wsHealth?.hasError == true ||
                      _apiHealth?.isDisconnected == true ||
                      _wsHealth?.isDisconnected == true)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const ConnectionStatusPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFFF3B30).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.wifiOff,
                                  size: 20,
                                  color: Color(0xFFFF3B30),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Connection Issues',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFFF3B30),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeColor.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.arrowLeft,
                                size: 20,
                                color: ThemeColor.textPrimary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: ThemeColor.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Settings Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Account Section (only when logged in)
                    if (widget.isLoggedIn) ...[
                      Text(
                        'settings.account_section'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Display Name (Editable with save button)
                      _AccountFieldWithSave(
                        icon: LucideIcons.user,
                        controller: _displayNameController,
                        onSave: _saveDisplayName,
                        isSaving: _isSavingDisplayName,
                      ),
                      const SizedBox(height: 12),

                      // Email (Read-only)
                      _AccountField(
                        icon: LucideIcons.mail,
                        value: _userEmail ?? 'No email',
                        isEditable: false,
                      ),
                      const SizedBox(height: 12),

                      // Account Created (Read-only)
                      _AccountField(
                        icon: LucideIcons.lock,
                        value: 'settings.account_created'.tr(
                          namedArgs: {'days': _daysAgoCreated.toString()},
                        ),
                        isEditable: false,
                      ),

                      const SizedBox(height: 32),
                      _SectionDivider(),
                      const SizedBox(height: 32),
                    ],

                    // Language Setting
                    _SettingRow(
                      label: 'settings.language'.tr(),
                      child: _DropdownButton(
                        value: _currentLanguageDisplay,
                        items: _languageLocales.keys.toList(),
                        onChanged: (value) {
                          final locale = _languageLocales[value];
                          if (locale != null) {
                            context.setLocale(locale);
                            setState(() {});
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    _SectionDivider(),
                    const SizedBox(height: 32),

                    // AI Section Header
                    Text(
                      'settings.ai_section'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeColor.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Model Setting
                    _SettingRow(
                      label: 'settings.model'.tr(),
                      child: _DropdownButton(
                        value: _selectedModel,
                        items: _models,
                        onChanged: (value) async {
                          setState(() {
                            _selectedModel = value;
                          });
                          // Save the selected model to preferences
                          await PreferencesService.setSelectedModel(value);
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Model Description
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'model_description.${_selectedModel.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_')}'
                            .tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: ThemeColor.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),

                    // Show iOS requirement for Apple Intelligence
                    if (_selectedModel == 'Apple Intelligence' && !_isIOS) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ThemeColor.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.info,
                                size: 16,
                                color: ThemeColor.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'settings.apple_intelligence_requirement'
                                      .tr(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: ThemeColor.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 60),
                    if (widget.isLoggedIn) ...[
                      Text(
                        'Offline Storage',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Storage Stats Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeColor.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _isLoadingOfflineStats
                            ? const Center(child: CupertinoActivityIndicator())
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: ThemeColor.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          LucideIcons.hardDrive,
                                          size: 20,
                                          color: ThemeColor.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Data available offline',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: ThemeColor.textPrimary,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _loadOfflineStats,
                                        child: const Icon(
                                          LucideIcons.refreshCw,
                                          size: 18,
                                          color: ThemeColor.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _OfflineStatRow(
                                    icon: LucideIcons.route,
                                    label: 'Saved Routes',
                                    value: _offlineStats['routesCount']
                                        .toString(),
                                  ),
                                  const SizedBox(height: 12),
                                  _OfflineStatRow(
                                    icon: LucideIcons.messageSquare,
                                    label: 'Conversations',
                                    value: _offlineStats['conversationsCount']
                                        .toString(),
                                  ),
                                  const SizedBox(height: 12),
                                  _OfflineStatRow(
                                    icon: LucideIcons.database,
                                    label: 'Storage Used',
                                    value: '${_offlineStats['totalSizeKB']} KB',
                                  ),
                                  const SizedBox(height: 16),
                                  // Download All Data button
                                  GestureDetector(
                                    onTap: _isDownloadingData ? null : _downloadAllData,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeColor.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: _isDownloadingData
                                          ? const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CupertinoActivityIndicator(radius: 10),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Downloading...',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: ThemeColor.primary,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  LucideIcons.download,
                                                  size: 16,
                                                  color: ThemeColor.primary,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Download All Data',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: ThemeColor.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Clear button
                                  GestureDetector(
                                    onTap: _clearOfflineData,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF3B30,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            LucideIcons.trash2,
                                            size: 16,
                                            color: Color(0xFFFF3B30),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Clear Offline Data',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFFFF3B30),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 32),
                      _SectionDivider(),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bottom Button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: GestureDetector(
                onTap: _handleAuthAction,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: ThemeColor.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isLoggedIn
                            ? LucideIcons.logOut
                            : LucideIcons.userPlus,
                        size: 20,
                        color: ThemeColor.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isLoggedIn
                            ? 'settings.disconnect'.tr()
                            : 'settings.connect'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  final IconData icon;
  final TextEditingController? controller;
  final String? value;
  final bool isEditable;

  const _AccountField({
    required this.icon,
    this.controller,
    this.value,
    required this.isEditable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEditable ? ThemeColor.inputBackground : ThemeColor.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 12),
            child: Icon(icon, size: 20, color: ThemeColor.textSecondary),
          ),
          Expanded(
            child: isEditable
                ? CupertinoTextField(
                    controller: controller,
                    decoration: null,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 0,
                    ),
                    style: const TextStyle(
                      color: ThemeColor.textPrimary,
                      fontSize: 16,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 0,
                    ),
                    child: Text(
                      value ?? '',
                      style: TextStyle(
                        color: ThemeColor.textSecondary.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _AccountFieldWithSave extends StatelessWidget {
  final IconData icon;
  final TextEditingController controller;
  final VoidCallback onSave;
  final bool isSaving;

  const _AccountFieldWithSave({
    required this.icon,
    required this.controller,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.inputBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 12),
            child: Icon(icon, size: 20, color: ThemeColor.textSecondary),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              decoration: null,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
              style: const TextStyle(
                color: ThemeColor.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          GestureDetector(
            onTap: isSaving ? null : onSave,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isSaving
                  ? const CupertinoActivityIndicator()
                  : const Icon(
                      LucideIcons.check,
                      size: 20,
                      color: ThemeColor.primary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: ThemeColor.textSecondary.withOpacity(0.1),
    );
  }
}

class _OfflineStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OfflineStatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: ThemeColor.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: ThemeColor.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ThemeColor.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: ThemeColor.textSecondary),
        ),
        child,
      ],
    );
  }
}

class _DropdownButton extends StatelessWidget {
  final String value;
  final List<String> items;
  final Function(String) onChanged;

  const _DropdownButton({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) => Container(
            height: 250,
            color: ThemeColor.background,
            child: CupertinoPicker(
              backgroundColor: ThemeColor.background,
              itemExtent: 40,
              scrollController: FixedExtentScrollController(
                initialItem: items.indexOf(value),
              ),
              onSelectedItemChanged: (int index) {
                onChanged(items[index]);
              },
              children: items.map((item) {
                return Center(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 18,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: ThemeColor.textPrimary),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: ThemeColor.textSecondary,
          ),
        ],
      ),
    );
  }
}
