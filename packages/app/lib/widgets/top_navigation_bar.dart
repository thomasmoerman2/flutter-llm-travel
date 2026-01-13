import 'package:flutter/cupertino.dart';
import '../services/theme_color.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TopNavigationBar extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onSettingsTap;

  const TopNavigationBar({super.key, this.onMenuTap, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconButton(icon: LucideIcons.menu, onTap: onMenuTap ?? () {}),
            _IconButton(
              icon: LucideIcons.settings,
              onTap: onSettingsTap ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeColor.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: ThemeColor.textPrimary, size: 24),
      ),
    );
  }
}
