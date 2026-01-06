import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/connection_health_service.dart';
import '../services/theme_color.dart';

class ConnectionStatusPage extends StatefulWidget {
  const ConnectionStatusPage({super.key});

  @override
  State<ConnectionStatusPage> createState() => _ConnectionStatusPageState();
}

class _ConnectionStatusPageState extends State<ConnectionStatusPage> {
  final ConnectionHealthService _healthService = ConnectionHealthService();
  ConnectionHealth? _apiHealth;
  ConnectionHealth? _wsHealth;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkConnections();
  }

  Future<void> _checkConnections() async {
    setState(() {
      _isChecking = true;
    });

    await _healthService.checkAllConnections();

    if (mounted) {
      setState(() {
        _apiHealth = _healthService.apiHealth;
        _wsHealth = _healthService.wsHealth;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('connection_status.title'.tr()),
        trailing: _isChecking
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _checkConnections,
                child: const Icon(LucideIcons.refreshCw, size: 20),
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Overview
            _buildStatusOverview(),

            const SizedBox(height: 24),

            // API Connection
            _buildConnectionCard(
              title: 'connection_status.api_connection'.tr(),
              health: _apiHealth,
              icon: LucideIcons.server,
            ),

            const SizedBox(height: 16),

            // Help Text
            if (_apiHealth?.hasError == true || _wsHealth?.hasError == true)
              _buildHelpSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview() {
    final hasIssues =
        _apiHealth?.hasError == true ||
        _wsHealth?.hasError == true ||
        _apiHealth?.isDisconnected == true ||
        _wsHealth?.isDisconnected == true;

    final allConnected =
        _apiHealth?.isConnected == true && _wsHealth?.isConnected == true;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (_isChecking) {
      statusColor = const Color(0xFFFF9500); // Orange
      statusIcon = LucideIcons.refreshCw;
      statusText = 'connection_status.checking'.tr();
    } else if (hasIssues) {
      statusColor = const Color(0xFFFF3B30); // Red
      statusIcon = LucideIcons.info;
      statusText = 'connection_status.issues_detected'.tr();
    } else if (allConnected) {
      statusColor = const Color(0xFF34C759); // Green
      statusIcon = LucideIcons.check;
      statusText = 'connection_status.all_systems_operational'.tr();
    } else {
      statusColor = const Color(0xFFFF9500); // Orange
      statusIcon = LucideIcons.info;
      statusText = 'connection_status.checking'.tr();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (!_isChecking && _apiHealth != null && _wsHealth != null)
                  Text(
                    'connection_status.last_checked'.tr(
                      namedArgs: {'time': _formatTime(_apiHealth!.lastChecked)},
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
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

  Widget _buildConnectionCard({
    required String title,
    required ConnectionHealth? health,
    required IconData icon,
  }) {
    if (health == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeColor.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: CupertinoColors.systemGrey),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
            const CupertinoActivityIndicator(),
          ],
        ),
      );
    }

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (health.isConnected) {
      statusColor = const Color(0xFF34C759); // Green
      statusIcon = LucideIcons.check;
      statusText = 'connection_status.connected'.tr();
    } else if (health.hasError) {
      statusColor = const Color(0xFFFF3B30); // Red
      statusIcon = LucideIcons.info;
      statusText = 'connection_status.error'.tr();
    } else {
      statusColor = const Color(0xFFFF9500); // Orange
      statusIcon = LucideIcons.info;
      statusText = 'connection_status.disconnected'.tr();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${'connection_status.status'.tr()}: ',
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 15,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (health.message != null && health.message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              health.message!,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.lightbulb,
                size: 20,
                color: Color(0xFFFF9500),
              ),
              const SizedBox(width: 8),
              Text(
                'connection_status.troubleshooting'.tr(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelpItem('connection_status.help_check_internet'.tr()),
          _buildHelpItem('connection_status.help_check_server'.tr()),
          _buildHelpItem('connection_status.help_check_env'.tr()),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 15)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'connection_status.just_now'.tr();
    } else if (difference.inMinutes < 60) {
      return 'connection_status.minutes_ago'.tr(
        namedArgs: {'count': difference.inMinutes.toString()},
      );
    } else {
      return 'connection_status.hours_ago'.tr(
        namedArgs: {'count': difference.inHours.toString()},
      );
    }
  }
}
