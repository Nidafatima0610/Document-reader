import 'package:flutter/material.dart';

/// Centralized, production-grade design system and theme definitions for All Documents Reader.
class AppTheme {
  // Brand & Semantic Colors
  static const Color primaryPurple = Color(0xFF7046A8);
  static const Color primaryPurpleDark = Color(0xFF9E7FE0);
  static const Color secondaryPurple = Color(0xFF8E24AA);
  static const Color primaryColor = primaryPurple;
  static const Color primaryDark = Color(0xFF5E35B1);
  static const Color primaryLight = primaryPurpleDark;

  // Semantic Document Type Colors
  static const Color pdfColor = Color(0xFFE53935);
  static const Color wordColor = Color(0xFF1E88E5);
  static const Color excelColor = Color(0xFF2E7D32);
  static const Color pptColor = Color(0xFFE65100);
  static const Color textColor = Color(0xFFF57C00);
  static const Color imageColor = Color(0xFF00897B);
  static const Color otherColor = Color(0xFF7046A8);

  // Surfaces & Backgrounds
  static const Color lightScaffoldBg = Color(0xFFF8F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFEDE6F5);
  static const Color lightTextPrimary = Color(0xFF261E2E);
  static const Color lightTextSecondary = Color(0xFF6E6476);

  static const Color darkScaffoldBg = Color(0xFF130F1A);
  static const Color darkSurface = Color(0xFF1F1A28);
  static const Color darkCardBorder = Color(0xFF2E2638);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB5ABC0);

  // LIGHT THEME
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      primary: primaryPurple,
      secondary: secondaryPurple,
      surface: lightSurface,
      brightness: Brightness.light,
      outline: const Color(0xFFD3C5E4),
      outlineVariant: lightCardBorder,
    ),
    scaffoldBackgroundColor: lightScaffoldBg,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: lightTextPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
        color: lightTextPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: lightTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: lightTextPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: lightTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: lightTextSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: lightTextSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: lightTextSecondary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightScaffoldBg,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: lightTextPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightCardBorder, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      indicatorColor: const Color(0xFFEFE6FA),
      elevation: 3,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: primaryPurple,
          );
        }
        return const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF787280),
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(primaryPurple),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(1),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightSurface,
      selectedColor: primaryPurple,
      disabledColor: const Color(0xFFF1EEF5),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: lightCardBorder, width: 1),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF261F2E),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: lightTextPrimary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  // DARK THEME
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurpleDark,
      primary: primaryPurpleDark,
      secondary: const Color(0xFFBA68C8),
      surface: darkSurface,
      brightness: Brightness.dark,
      outline: const Color(0xFF433852),
      outlineVariant: darkCardBorder,
    ),
    scaffoldBackgroundColor: darkScaffoldBg,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: darkTextPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
        color: darkTextPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: darkTextPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: darkTextPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: darkTextPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: darkTextSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: darkTextSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: darkTextPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: darkTextSecondary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkScaffoldBg,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: darkTextPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkCardBorder, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1422),
      indicatorColor: const Color(0xFF38294D),
      elevation: 3,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFBCA1E6),
          );
        }
        return const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF9E96A6),
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(primaryPurpleDark),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFF14101A)),
        elevation: const WidgetStatePropertyAll(1),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkSurface,
      selectedColor: primaryPurpleDark,
      disabledColor: const Color(0xFF272130),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkCardBorder, width: 1),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF2B2238),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: darkTextPrimary,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
