import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/mapbox_directions_service.dart';
import '../services/theme_color.dart';

class RouteOptionCard extends StatelessWidget {
  final RouteOption option;
  final VoidCallback onTap;

  const RouteOptionCard({super.key, required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Calculate estimated distance for display
    double totalDistance = 0;
    if (option.locations.length >= 2) {
      for (int i = 0; i < option.locations.length - 1; i++) {
        totalDistance += MapboxDirectionsService.calculateDistance(
          option.locations[i].latitude,
          option.locations[i].longitude,
          option.locations[i + 1].latitude,
          option.locations[i + 1].longitude,
        );
      }
    }

    final distanceText = totalDistance < 1
        ? '${(totalDistance * 1000).toInt()} m'
        : '${totalDistance.toStringAsFixed(1)} km';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeColor.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColor.divider, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: ThemeColor.textSecondary,
                ),
              ],
            ),
            if (option.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                option.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: ThemeColor.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 12,
                        color: ThemeColor.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${option.locations.length} stops',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ThemeColor.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeColor.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.moveHorizontal,
                        size: 12,
                        color: ThemeColor.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ThemeColor.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
