import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/chat_message.dart';
import '../services/firestore_access.dart';
import '../services/theme_color.dart';

class ConversationSidebar extends StatelessWidget {
  final double width;
  final String? selectedConversationId;
  final VoidCallback onNewConversation;
  final ValueChanged<Conversation> onSelectConversation;
  final ValueChanged<Conversation> onDeleteConversation;

  const ConversationSidebar({
    super.key,
    required this.width,
    required this.selectedConversationId,
    required this.onNewConversation,
    required this.onSelectConversation,
    required this.onDeleteConversation,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: ThemeColor.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ThemeColor.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onNewConversation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: ThemeColor.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.plus,
                          size: 14,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'New conversation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: user == null
                    ? const Center(
                        child: Text(
                          'Log in to see your conversations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ThemeColor.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : StreamBuilder<List<Conversation>>(
                        stream: FirestoreAccess().getConversations(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CupertinoActivityIndicator(),
                            );
                          }

                          final conversations = snapshot.data ?? [];
                          if (conversations.isEmpty) {
                            return const Center(
                              child: Text(
                                'No conversations yet.',
                                style: TextStyle(
                                  color: ThemeColor.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: conversations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final conversation = conversations[index];
                              final isSelected =
                                  conversation.id == selectedConversationId;
                              final title = conversation.title.trim().isEmpty
                                  ? 'New Conversation'
                                  : conversation.title;
                              final time = _formatRelativeTime(
                                conversation.updatedAt,
                              );
                              final isModelUnavailable =
                                  conversation.currentModel ==
                                  'Apple Intelligence';

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ThemeColor.divider
                                      : ThemeColor.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _handleConversationTap(
                                          context,
                                          conversation,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: ThemeColor
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (isModelUnavailable) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    LucideIcons.circleAlert,
                                                    size: 14,
                                                    color: Color(0xFFFF9500),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  time,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: ThemeColor
                                                        .textSecondary,
                                                  ),
                                                ),
                                                if (isModelUnavailable) ...[
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    '• Model unavailable',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFFFF9500),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () =>
                                          _confirmDelete(context, conversation),
                                      child: const Icon(
                                        LucideIcons.trash2,
                                        size: 16,
                                        color: ThemeColor.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleConversationTap(BuildContext context, Conversation conversation) {
    // Check if the conversation uses an unavailable model
    final model = conversation.currentModel;
    final isUnavailable = model == 'Apple Intelligence';

    if (isUnavailable) {
      _showUnavailableModelDialog(context, conversation, model);
    } else {
      onSelectConversation(conversation);
    }
  }

  void _showUnavailableModelDialog(
    BuildContext context,
    Conversation conversation,
    String model,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Model Not Available'),
        content: Text(
          'This conversation uses "$model" which is currently unavailable.\n\n'
          'Reason: Apple Intelligence is not supported in your region or device.\n\n'
          'If you open this conversation, it will automatically switch to ChatGPT so you can continue chatting.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Open anyway'),
            onPressed: () {
              Navigator.pop(context);
              onSelectConversation(conversation);
            },
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  void _confirmDelete(BuildContext context, Conversation conversation) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This will permanently remove the conversation and its messages.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              onDeleteConversation(conversation);
            },
          ),
        ],
      ),
    );
  }
}
