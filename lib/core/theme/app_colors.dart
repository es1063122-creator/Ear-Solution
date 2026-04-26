import 'package:flutter/material.dart';

class AppColors {
  static const Color greenDark  = Color(0xFF1E3932);
  static const Color green      = Color(0xFF00704A);
  static const Color greenLight = Color(0xFFD4E9E2);
  static const Color greenMid   = Color(0xFF4A6741);
  static const Color gold       = Color(0xFFCBA258);
  static const Color cream      = Color(0xFFF2F0EB);
  static const Color cream2     = Color(0xFFE8E4DC);
  static const Color white      = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E3932);
  static const Color textSecond  = Color(0xFF4A6741);
  static const Color textLight   = Color(0xFF7A9E8E);
  static const Color textHint    = Color(0xFFB5C9BF);
  static const Color error       = Color(0xFFD32F2F);
  static const Color warning     = Color(0xFFF57C00);
  static const Color success     = Color(0xFF388E3C);

  static Color intensityColor(int level) {
    if (level <= 3) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
