import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFF7046A8)),
        foregroundColor: WidgetStatePropertyAll(Color(0xFFFFFFFF)),
        elevation: WidgetStatePropertyAll(2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        color: Color(0xFF4A3A52),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Color(0xFF625D68), fontSize: 15),
    ),
    cardTheme: CardThemeData(
      color: Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFFD9BCEB),
      foregroundColor: Color(0xFF25212B),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      indicatorColor: Color(0xFFE3D5F0),
      elevation: 2,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Color(0xFFE3D5F0),
    colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF6C4AB6)),
  );
  static ThemeData darkTheme = ThemeData(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xFF9B7DD4)),
        foregroundColor: WidgetStatePropertyAll(Color(0xFF15121A)),
        elevation: WidgetStatePropertyAll(2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        color: Color(0xFFFFFFFF),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(color: Color(0xFFD0CBD5), fontSize: 15),
    ),
    cardTheme: CardThemeData(
      color: Color(0xFF211C29),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF1D1824),
      foregroundColor: Color(0xFFFFFFFF),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Color(0xFF1D1824),
      indicatorColor: Color(0xFF3A2D49),
      elevation: 2,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: Color(0xFF15121A),
    colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF9B7DD4)),
  );
}
