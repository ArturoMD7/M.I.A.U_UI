import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFD0894B);
  static const Color secondary = Color(0xFF8B5A2B);
  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
  static const Color accent = Color(0xFFD68F5E);
  static const Color error = Colors.red;
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;

  static const Color lostPetColor = Colors.red;
  static const Color adoptPetColor = Color(0xFF4CAF50);
  static const Color qrScannerColor = primary;

  static Color getBackgroundColor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xFF1E1E1E) : background;
  }

  static Color getCardColor(Brightness brightness) {
    return brightness == Brightness.dark ? const Color(0xFF2D2D2D) : card;
  }

  static Color getTextPrimaryColor(Brightness brightness) {
    return brightness == Brightness.dark ? Colors.white : textPrimary;
  }

  static Color getTextSecondaryColor(Brightness brightness) {
    return brightness == Brightness.dark ? Colors.white70 : textSecondary;
  }
}
