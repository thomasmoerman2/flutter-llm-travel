import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/theme_color.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: ThemeColor.surface,
                borderRadius: BorderRadius.circular(44),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _NavButton(
                      icon: LucideIcons.messageCircle,
                      isActive: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    const SizedBox(width: 16),
                    _NavButton(
                      icon: LucideIcons.map,
                      isActive: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? ThemeColor.divider : ThemeColor.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: ThemeColor.iconDefault, size: 24),
      ),
    );
  }
}
