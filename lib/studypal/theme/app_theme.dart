import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Soft, elegant gradient colors for animated backgrounds
  // These gradients transition smoothly from top to bottom for a professional look

  // Primary: Blue-purple to light blue gradient
  static const List<Color> primaryGradient = [
    Color(0xFF8A6CF6), // Soft Purple
    Color(0xFFFFB74D), // Warm Orange
    Color(0xFF4DD0E1), // Teal
  ];

  // Secondary: Purple to lavender gradient
  static const List<Color> secondaryGradient = [
    Color(0xFF5E6B9E), // Soft purple-blue
    Color(0xFF8A96C4), // Mid purple
    Color(0xFFD9E3F0), // Very light purple
  ];

  // Accent: Blue-purple to pale blue gradient
  static const List<Color> accentGradient = [
    Color(0xFF6B7AA8), // Soft blue-purple
    Color(0xFF9DB3D9), // Mid light blue
    Color(0xFFE8EFF8), // Very pale blue
  ];

  // Standard AppBar style
  static AppBarTheme get appBarTheme {
    return AppBarTheme(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // Standard scaffold background
  static const Color scaffoldBackground = Colors.white;

  // Consistent button style
  static ButtonStyle get elevatedButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }

  // Consistent outlined button style
  static ButtonStyle get outlinedButtonStyle {
    return OutlinedButton.styleFrom(
      side: const BorderSide(color: AppColors.primary, width: 2),
      foregroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }

  // Input decoration style
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  // Card style
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.1),
          blurRadius: 10,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}
