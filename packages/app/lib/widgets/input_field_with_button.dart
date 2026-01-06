import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/theme_color.dart';

class InputFieldWithButton extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final VoidCallback? onSend;
  final Function(String)? onSubmitted;

  const InputFieldWithButton({
    super.key,
    this.controller,
    required this.hintText,
    this.onSend,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: ThemeColor.inputBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: CupertinoTextField(
                controller: controller,
                onSubmitted: onSubmitted,
                placeholder: hintText,
                placeholderStyle: const TextStyle(
                  color: ThemeColor.textSecondary,
                  fontSize: 16,
                ),
                decoration: null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                style: const TextStyle(
                  color: ThemeColor.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: ThemeColor.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.arrowRight,
                color: ThemeColor.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
