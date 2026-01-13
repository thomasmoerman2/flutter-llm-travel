import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../models/chat_message.dart';
import '../services/theme_color.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showModel;
  final VoidCallback? onShowOnMap;
  final void Function(String text)? onResend;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.showModel = false,
    this.onShowOnMap,
    this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final showMapAction =
        !isUser &&
        !message.hasError &&
        (message.hasLocations || message.hasRoute);
    final mapActionLabel = message.hasRoute ? 'Show route' : 'Show on map';

    if (!isUser) {
      debugPrint('🎨 ChatMessageBubble: isUser=$isUser, hasError=${message.hasError}, hasLocations=${message.hasLocations}, hasRoute=${message.hasRoute}, showMapAction=$showMapAction');
      if (message.metadata != null) {
        debugPrint('   Metadata keys: ${message.metadata!.keys.join(", ")}');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[_buildAvatar(false), const SizedBox(width: 12)],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.hasError
                      ? (isUser
                            ? ThemeColor.primary.withOpacity(0.8)
                            : const Color(
                                0xFFFFEBEE,
                              )) // Light red for error messages
                      : (isUser ? ThemeColor.primary : ThemeColor.surface),
                  borderRadius: BorderRadius.circular(20),
                  border: message.hasError
                      ? Border.all(
                          color: const Color(
                            0xFFEF5350,
                          ), // Red border for errors
                          width: 1,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Model header for AI messages
                  if (!isUser && showModel) ...[
                    Row(
                      children: [
                        Icon(
                          _getModelIcon(message.model),
                          size: 14,
                          color: ThemeColor.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          message.model,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ThemeColor.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Message content
                  MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 16,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                        height: 1.4,
                      ),
                      strong: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                      em: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                      code: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        backgroundColor: isUser
                            ? ThemeColor.background.withOpacity(0.2)
                            : ThemeColor.surface,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isUser
                            ? ThemeColor.background.withOpacity(0.2)
                            : ThemeColor.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquote: TextStyle(
                        fontSize: 16,
                        color: isUser
                            ? ThemeColor.background.withOpacity(0.8)
                            : ThemeColor.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      h1: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                      h2: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                      h3: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                      listBullet: TextStyle(
                        fontSize: 16,
                        color: isUser
                            ? ThemeColor.background
                            : ThemeColor.textPrimary,
                      ),
                    ),
                    selectable: true,
                  ),

                  // Show on Map button (for AI messages with locations/routes)
                  if (showMapAction && onShowOnMap != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onShowOnMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeColor.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.map,
                              size: 16,
                              color: ThemeColor.background,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mapActionLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ThemeColor.background,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Status indicators
                  if ((message.isStreaming || message.isSending) &&
                      !message.hasError) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CupertinoActivityIndicator(
                            color: isUser
                                ? ThemeColor.background
                                : ThemeColor.textSecondary,
                            radius: 6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          message.isStreaming ? 'Typing...' : 'Sending...',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUser
                                ? ThemeColor.background.withOpacity(0.8)
                                : ThemeColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Error indicator
                  if (message.hasError) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.circleAlert,
                          size: 14,
                          color: isUser
                              ? ThemeColor.background
                              : const Color(
                                  0xFFEF5350,
                                ), // Red color for error icon
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isUser
                                ? ThemeColor.background.withOpacity(0.8)
                                : const Color(
                                    0xFFEF5350,
                                  ), // Red color for error text
                          ),
                        ),
                      ],
                    ),
                  ],

                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser
                            ? ThemeColor.background.withOpacity(0.7)
                            : ThemeColor.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[const SizedBox(width: 12), _buildAvatar(true)],
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    final actions = <CupertinoActionSheetAction>[
      CupertinoActionSheetAction(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: message.content));
          Navigator.pop(context);
        },
        child: const Text('Copy'),
      ),
    ];

    if (message.isUser && onResend != null) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onResend?.call(message.content);
          },
          child: const Text('Resend'),
        ),
      );
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays < 7) {
      return DateFormat('E HH:mm').format(timestamp); // e.g., "Mon 14:30"
    } else {
      return DateFormat(
        'MMM d, HH:mm',
      ).format(timestamp); // e.g., "Jan 6, 14:30"
    }
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? ThemeColor.primary : ThemeColor.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? LucideIcons.user : _getModelIcon(message.model),
        size: 16,
        color: isUser ? ThemeColor.background : ThemeColor.textPrimary,
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
        return LucideIcons.cpu;
      case 'Hybrid':
        return LucideIcons.zap;
      default:
        return LucideIcons.bot;
    }
  }
}
