import 'package:flutter/material.dart';

class AppColors {
  // primary palette from your logos
  static const Color blue500 = Color(0xFF2196F3); // main blue
  static const Color blue600 = Color(0xFF1976D2); // darker blue
  static const Color ice = Color(0xFFF5F7FA);     // soft gray-white background
  static const Color slate900 = Color(0xFF0F1720); // dark background
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF0E1620);
}

class AppThemes {
  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.blue500,
    scaffoldBackgroundColor: AppColors.ice,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black87,
    ),
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      elevation: 6,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16),
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.blue500,
      secondary: AppColors.blue600,
    ),
  );

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.blue500,
    scaffoldBackgroundColor: AppColors.slate900,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      elevation: 6,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16),
    ),
    colorScheme: ColorScheme.dark(
      primary: AppColors.blue500,
      secondary: AppColors.blue600,
    ),
  );

  // a small gradient helper
  static LinearGradient primaryGradient({bool dark = false}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [AppColors.blue600.withOpacity(0.95), AppColors.blue500]
          : [AppColors.blue500, AppColors.blue600.withOpacity(0.95)],
    );
  }
}
