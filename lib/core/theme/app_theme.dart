import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.brandGold,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.brandPrimary,
          secondary: AppColors.brandGold,
          error: AppColors.brandRed,
          surface: AppColors.surface,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.brandPrimary,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
