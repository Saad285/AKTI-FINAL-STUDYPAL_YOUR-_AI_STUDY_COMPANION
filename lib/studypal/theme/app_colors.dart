import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Main Palette ---
  static const Color primary = Color(0xFF7A8BCC);
  static const Color primaryVariant = Color(0xFFFFDDAA);
  static const Color secondary = Color.fromARGB(255, 3, 164, 218);
  static const Color secondaryVariant = Color(0xFF018786);

  // --- Backgrounds ---
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(
    0xFFFFFFFF,
  ); // Used for cards, sheets, etc.

  // --- Text & Icons ---
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onBackground = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);

  // --- Feedback ---
  static const Color error = Color(0xFFB00020);
  static const Color onError = Color(0xFFFFFFFF);

  // --- Neutrals ---
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFF5F5F5);

  static const List<Color> aestheticColors = [
    Color(0xFF81C784), // Light Green
    Color(0xFFFFB74D), // Light Orange/Amber
    Color(0xFF64B5F6), // Sky Blue
    Color(0xFFBA68C8), // Light Purple
    Color(0xFFE57373), // Light Red/Coral
    Color(0xFFA1887F), // Brownish Grey
    Color(0xFF90A4AE), // Blue Grey
    Color(0xFFFF8A65), // Peach/Salmon
    Color(0xFF4DB6AC), // Teal
    Color(0xFF7986CB), // Indigo/Lavender
  ];
}
