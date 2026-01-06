import 'package:flutter/cupertino.dart';
import '../services/theme_color.dart';

/// Content-only widget for the map page (without navigation)
/// Used inside RootLayout
class MapPageContent extends StatelessWidget {
  const MapPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Map Page',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: ThemeColor.textPrimary,
        ),
      ),
    );
  }
}
