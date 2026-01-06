import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/theme_color.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onMapActionTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onMapActionTap,
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
          const Spacer(),
          if (onMapActionTap != null)
            SafeArea(
              top: false,
              child: GestureDetector(
                onTap: onMapActionTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ThemeColor.primary,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.list,
                    size: 22,
                    color: ThemeColor.background,
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
