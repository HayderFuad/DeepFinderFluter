import 'package:flutter/material.dart';

/// Material Design 3 Light & Dark Themes tailored for Arabic RTL readability.
class AppTheme {
  AppTheme._();

  static const Color primarySeedLight = Color(0xFF0B57D0);
  static const Color primarySeedDark = Color(0xFFA8C7FA);

  // File Category Colors
  static const Color pdfColor = Color(0xFFE53935);
  static const Color wordColor = Color(0xFF1E88E5);
  static const Color excelColor = Color(0xFF2E7D32);
  static const Color folderColor = Color(0xFFF9A825);
  static const Color textColor = Color(0xFF7B1FA2);
  static const Color otherFileColor = Color(0xFF546E7A);

  // Highlight Colors for Matched Search Words
  static const Color highlightBgLight = Color(0xFFFFF59D);
  static const Color highlightFgLight = Color(0xFF3E2723);
  static const Color highlightBgDark = Color(0xFF795548);
  static const Color highlightFgDark = Color(0xFFFFF8E1);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeedLight,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFD),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primarySeedDark,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0E131A),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
