import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      primary: AppColors.green,
      secondary: AppColors.gold,
      surface: AppColors.cream,
      background: AppColors.cream,
      onPrimary: AppColors.white,
      onBackground: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.greenDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.greenDark,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.greenLight, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.green,
      unselectedItemColor: AppColors.textLight,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.greenDark),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.greenDark),
      titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.greenDark),
      titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.greenDark),
      bodyLarge:      TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodyMedium:     TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecond),
      bodySmall:      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textLight),
      labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textLight),
    ),
  );
}
