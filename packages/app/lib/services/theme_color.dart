import 'package:flutter/cupertino.dart';

class ThemeColor {
  const ThemeColor._();

  // Primary colors
  static const Color primary = Color(0xFF46DE7F); // Green - master/main color
  static const Color secondary = Color(
    0xFFCECECE,
  ); // Gray - second color (button)
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);

  // Text colors
  static const Color textPrimary = Color(
    0xFF090909,
  ); // Black - master black color
  static const Color textSecondary = Color(0xFF666666);

  // UI Element colors
  static const Color inputBackground = Color(0xFFF0F0F0);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFE0E0E0);

  // Accent colors
  static const Color accent = Color(0xFF4A90E2);
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(
    0xFF46DE7F,
  ); // Use primary green for success

  // Transparent color
  static const Color transparent = Color(0x00000000);
}
